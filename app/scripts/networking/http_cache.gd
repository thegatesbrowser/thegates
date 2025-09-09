extends RefCounted

class_name HTTPCache

const CACHE_INDEX_FILE := "cache_index.json"
const HEURISTIC_MIN_TTL_SECS := 3

var download_folder: String
var cache_index_path: String
var cache_index: Dictionary = {}


func _init(folder: String) -> void:
	download_folder = folder
	cache_index_path = download_folder.rstrip("/") + "/" + CACHE_INDEX_FILE
	DirAccess.make_dir_recursive_absolute(download_folder)
	load_index()


func is_fresh(save_path: String) -> bool:
	var meta: Dictionary = cache_index.get(save_path, {})
	if meta.has("no_cache") and bool(meta["no_cache"]):
		return false
	if meta.has("expiry"):
		var expiry: int = int(meta["expiry"])
		return expiry > int(Time.get_unix_time_from_system())
	return false


func get_expiry_timestamp(save_path: String) -> int:
	# Returns unix timestamp (UTC seconds) when the cached entry expires, or 0 if unknown.
	var meta: Dictionary = cache_index.get(save_path, {})
	if meta.has("expiry"):
		return int(meta["expiry"])
	return 0


func get_minutes_until_expiry(save_path: String) -> int:
	# Returns remaining time until expiry in whole minutes. 0 if expired/unknown.
	var expiry: int = get_expiry_timestamp(save_path)
	if expiry <= 0:
		return 0
	var now: int = int(Time.get_unix_time_from_system())
	var remaining: int = expiry - now
	if remaining <= 0:
		return 0
	return int(ceil(float(remaining) / 60.0))


func build_conditional_headers(save_path: String, file_exists: bool, force_revalidate: bool) -> PackedStringArray:
	var headers := PackedStringArray()
	var meta: Dictionary = cache_index.get(save_path, {})
	# Only send conditional validators if the local file exists; otherwise we risk a 304 with no file on disk.
	if file_exists:
		if meta.has("etag") and String(meta["etag"]).length() > 0:
			headers.append("If-None-Match: " + String(meta["etag"]))
		elif meta.has("last_modified") and String(meta["last_modified"]).length() > 0:
			headers.append("If-Modified-Since: " + String(meta["last_modified"]))
	if force_revalidate:
		headers.append("Cache-Control: no-cache")
		headers.append("Pragma: no-cache")
	return headers


func update_from_response(save_path: String, url: String, response_headers: PackedStringArray, status_code: int) -> void:
	var header_map := headers_to_map(response_headers)
	var meta: Dictionary = cache_index.get(save_path, {})
	meta["url"] = url
	if header_map.has("etag"):
		meta["etag"] = String(header_map["etag"])
	if header_map.has("last-modified"):
		meta["last_modified"] = String(header_map["last-modified"])

	# Compute caching policy:
	# - Respect no-cache/must-revalidate
	# - Prefer heuristic TTL = 10% of age since last modification (based on server Date when available)
	# - Cap heuristic TTL by Cache-Control max-age when provided
	var now: int = int(Time.get_unix_time_from_system())
	var expiry: int = 0
	var no_cache := false
	var max_age: int = 0
	if header_map.has("cache-control"):
		var cc := String(header_map["cache-control"]).to_lower()
		var flags := parse_cache_flags(cc)
		no_cache = bool(flags.get("no_cache", false)) or bool(flags.get("must_revalidate", false))
		max_age = int(flags.get("max_age", 0))

	# Use server Date header to avoid client clock skew when computing age
	var server_date_ts: int = 0
	if header_map.has("date"):
		server_date_ts = HTTPDateUtils.parse_http_date_rfc1123(String(header_map["date"]))
	var now_ref: int = server_date_ts if server_date_ts > 0 else now

	var last_modified_str := ""
	if header_map.has("last-modified"):
		last_modified_str = String(header_map["last-modified"])
	elif meta.has("last_modified"):
		# 304 responses may omit Last-Modified; reuse stored value
		last_modified_str = String(meta["last_modified"])

	var last_modified_ts: int = 0
	if not last_modified_str.is_empty():
		last_modified_ts = HTTPDateUtils.parse_http_date_rfc1123(last_modified_str)

	var ttl_from_lm: int = 0
	var age_seconds: int = 0
	if last_modified_ts > 0:
		age_seconds = now_ref - last_modified_ts
		if age_seconds > 0:
			# 10% heuristic with minimum floor to avoid truncation to 0 for fresh updates
			ttl_from_lm = max(int(ceil(float(age_seconds) / 10.0)), HEURISTIC_MIN_TTL_SECS)
		else:
			# If server time indicates Last-Modified is in the future or equal, use a tiny heuristic TTL
			ttl_from_lm = HEURISTIC_MIN_TTL_SECS
	elif header_map.has("last-modified"):
		# LM was present but failed to parse -> still use a tiny heuristic TTL to avoid inflating to max-age
		ttl_from_lm = HEURISTIC_MIN_TTL_SECS

	var ttl: int = 0
	if ttl_from_lm > 0 and max_age > 0:
		ttl = min(ttl_from_lm, max_age)
	elif ttl_from_lm > 0:
		ttl = ttl_from_lm
	elif max_age > 0:
		ttl = max_age
	elif status_code == 304 and meta.has("expiry"):
		# No explicit validators and no max-age on 304; keep current expiry to avoid immediate re-download loop
		ttl = max(0, int(meta["expiry"]) - now)

	# Debug: log cache decision for visibility
	print("[HTTPCache] url=", url,
		" status=", status_code,
		" lm=", last_modified_str,
		" server_date=", (String(header_map.get("date", "")) if header_map.has("date") else ""),
		" age_s=", age_seconds,
		" ttl_heuristic=", ttl_from_lm,
		" max_age=", max_age,
		" ttl_final=", ttl,
		" no_cache=", str(no_cache))

	if not no_cache and ttl > 0:
		expiry = now + ttl
		meta["expiry"] = expiry
	meta["no_cache"] = no_cache
	cache_index[save_path] = meta
	save_index()


func load_index() -> void:
	if FileAccess.file_exists(cache_index_path):
		var content := FileAccess.get_file_as_string(cache_index_path)
		if content.is_empty():
			cache_index = {}
			return
		var data = JSON.parse_string(content)
		if typeof(data) == TYPE_DICTIONARY:
			cache_index = data
		else:
			cache_index = {}
	else:
		cache_index = {}


func save_index() -> void:
	var json := JSON.stringify(cache_index)
	var file := FileAccess.open(cache_index_path, FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.flush()
		file.close()


func headers_to_map(headers: PackedStringArray) -> Dictionary:
	var map: Dictionary = {}
	for line in headers:
		var parts := line.split(":", false, 1)
		if parts.size() >= 2:
			var key := String(parts[0]).strip_edges().to_lower()
			var value := String(parts[1]).strip_edges()
			map[key] = value
	return map


func parse_cache_flags(cache_control: String) -> Dictionary:
	var info: Dictionary = {
		"no_cache": false,
		"must_revalidate": false,
		"immutable": false,
		"max_age": 0,
	}
	var parts := cache_control.split(",")
	for p in parts:
		var item := String(p).strip_edges()
		if item == "no-cache":
			info["no_cache"] = true
		elif item == "must-revalidate":
			info["must_revalidate"] = true
		elif item == "immutable":
			info["immutable"] = true
		elif item.begins_with("max-age="):
			var value := item.substr(8, item.length() - 8)
			if value.is_valid_int():
				info["max_age"] = int(value)
	return info

# TODO: cleanup ai generated code

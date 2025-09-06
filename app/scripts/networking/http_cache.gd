extends RefCounted

class_name HttpCache

const CACHE_INDEX_FILE := "cache_index.json"

var download_folder: String
var cache_index_path: String
var cache_index: Dictionary = {}


func initialize(folder: String) -> void:
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


func build_conditional_headers(save_path: String, force_revalidate: bool) -> PackedStringArray:
	var headers := PackedStringArray()
	var meta: Dictionary = cache_index.get(save_path, {})
	if meta.has("etag") and String(meta["etag"]).length() > 0:
		headers.append("If-None-Match: " + String(meta["etag"]))
	elif meta.has("last_modified") and String(meta["last_modified"]).length() > 0:
		headers.append("If-Modified-Since: " + String(meta["last_modified"]))
	if force_revalidate:
		headers.append("Cache-Control: no-cache")
		headers.append("Pragma: no-cache")
	return headers


func update_from_response(save_path: String, url: String, response_headers: PackedStringArray, _status_code: int) -> void:
	var header_map := headers_to_map(response_headers)
	var meta: Dictionary = cache_index.get(save_path, {})
	meta["url"] = url
	if header_map.has("etag"):
		meta["etag"] = String(header_map["etag"])
	if header_map.has("last-modified"):
		meta["last_modified"] = String(header_map["last-modified"])

	var expiry: int = 0
	var no_cache := false
	if header_map.has("cache-control"):
		var cc := String(header_map["cache-control"]).to_lower()
		var flags := parse_cache_flags(cc)
		no_cache = bool(flags.get("no_cache", false)) or bool(flags.get("must_revalidate", false)) or int(flags.get("max_age", 0)) == 0
		var max_age := int(flags.get("max_age", 0))
		if max_age > 0 and not no_cache:
			expiry = int(Time.get_unix_time_from_system()) + max_age
	if expiry > 0:
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



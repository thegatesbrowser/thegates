extends RefCounted
class_name HttpClientRequest

signal request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray)

var download_file: String
var use_threads: bool
var timeout: float

var expected_size: int
var downloaded_bytes: int
var cancel_token: HttpConnectionPool.CancelToken


func request(url: String, headers: PackedStringArray = PackedStringArray(), method: int = HTTPClient.METHOD_GET, data: String = "") -> Error:
	cancel_token = HttpConnectionPool.create_cancel_token()
	perform(url, headers, method, data)
	return OK


func request_raw(url: String, headers: PackedStringArray = PackedStringArray(), method: int = HTTPClient.METHOD_GET, data: PackedByteArray = PackedByteArray()) -> Error:
	cancel_token = HttpConnectionPool.create_cancel_token()
	perform_raw(url, headers, method, data)
	return OK


func cancel_request() -> void:
	if cancel_token != null:
		cancel_token.cancelled = true


func get_body_size() -> int:
	return expected_size


func get_downloaded_bytes() -> int:
	return downloaded_bytes


func progress_cb(headers_phase: bool, content_length: int, downloaded: int) -> void:
	if headers_phase:
		expected_size = content_length
	else:
		downloaded_bytes = downloaded


func perform(url: String, headers: PackedStringArray, method: int, data: String) -> void:
	var res: Dictionary = await HttpConnectionPool.request(url, headers, method, data, timeout, cancel_token)
	if res.get("headers") != null:
		# Set size if available
		var hdrs: PackedStringArray = res["headers"]
		for line in hdrs:
			if line.to_lower().begins_with("content-length:"):
				var parts := line.split(":", false, 1)
				if parts.size() == 2 and String(parts[1]).strip_edges().is_valid_int():
					expected_size = int(String(parts[1]).strip_edges())
	if not res.has("body"):
		res["body"] = PackedByteArray()
	if not download_file.is_empty() and res.get("result", ERR_DOES_NOT_EXIST) == OK and res.get("code", 0) >= 200 and res.get("code", 0) < 400:
		var dir := download_file.get_base_dir()
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(download_file, FileAccess.WRITE)
		if f:
			f.store_buffer(res["body"])
			f.flush()
			f.close()
		downloaded_bytes = res["body"].size()
	request_completed.emit(res.get("result", ERR_DOES_NOT_EXIST), res.get("code", 0), res.get("headers", PackedStringArray()), res.get("body", PackedByteArray()))


func perform_raw(url: String, headers: PackedStringArray, method: int, data: PackedByteArray) -> void:
	var res: Dictionary = await HttpConnectionPool.request_raw(url, headers, method, data, timeout, cancel_token)
	if res.get("headers") != null:
		var hdrs: PackedStringArray = res["headers"]
		for line in hdrs:
			if line.to_lower().begins_with("content-length:"):
				var parts := line.split(":", false, 1)
				if parts.size() == 2 and String(parts[1]).strip_edges().is_valid_int():
					expected_size = int(String(parts[1]).strip_edges())
	if not res.has("body"):
		res["body"] = PackedByteArray()
	if not download_file.is_empty() and res.get("result", ERR_DOES_NOT_EXIST) == OK and res.get("code", 0) >= 200 and res.get("code", 0) < 400:
		var dir := download_file.get_base_dir()
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open(download_file, FileAccess.WRITE)
		if f:
			f.store_buffer(res["body"])
			f.flush()
			f.close()
		downloaded_bytes = res["body"].size()
	request_completed.emit(res.get("result", ERR_DOES_NOT_EXIST), res.get("code", 0), res.get("headers", PackedStringArray()), res.get("body", PackedByteArray()))

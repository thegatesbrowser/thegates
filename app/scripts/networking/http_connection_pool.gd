extends RefCounted
class_name HttpConnectionPool

const DEFAULT_TIMEOUT_SEC := 30.0
const ERR_CANCELED := 10001

class ConnectionEntry:
	var client: HTTPClient
	var host: String
	var port: int
	var use_tls: bool
	var busy: bool
	var last_used_ms: int

	func _init(_client: HTTPClient, _host: String, _port: int, _use_tls: bool) -> void:
		client = _client
		host = _host
		port = _port
		use_tls = _use_tls
		busy = false
		last_used_ms = Time.get_ticks_msec()


var pools: Dictionary = {} # key -> Array[ConnectionEntry]

static var _instance: HttpConnectionPool

static func get_singleton() -> HttpConnectionPool:
	if _instance == null:
		_instance = HttpConnectionPool.new()
	return _instance


class CancelToken:
	var cancelled: bool = false

static func create_cancel_token() -> CancelToken:
	return CancelToken.new()


func request(url: String, headers: PackedStringArray = PackedStringArray(), method: int = HTTPClient.METHOD_GET, body: String = "", timeout_sec: float = DEFAULT_TIMEOUT_SEC, token: CancelToken = null) -> Dictionary:
	var parsed = _parse_url(url)
	if parsed == null:
		return {"result": ERR_INVALID_PARAMETER}
	var path: String = parsed["path"]
	var entry: ConnectionEntry = await _acquire_connection(parsed["host"], parsed["port"], parsed["tls"], timeout_sec, token)
	if entry == null:
		return {"result": ERR_CANT_CONNECT}
	var client := entry.client
	entry.busy = true
	if token != null and token.cancelled:
		entry.busy = false
		return {"result": ERR_CANCELED}
	var result := await _perform_request_str(client, method, path, headers, body, timeout_sec, token)
	entry.busy = false
	entry.last_used_ms = Time.get_ticks_msec()
	return result


func request_raw(url: String, headers: PackedStringArray = PackedStringArray(), method: int = HTTPClient.METHOD_GET, body: PackedByteArray = PackedByteArray(), timeout_sec: float = DEFAULT_TIMEOUT_SEC, token: CancelToken = null) -> Dictionary:
	var parsed = _parse_url(url)
	if parsed == null:
		return {"result": ERR_INVALID_PARAMETER}
	var path: String = parsed["path"]
	var entry: ConnectionEntry = await _acquire_connection(parsed["host"], parsed["port"], parsed["tls"], timeout_sec, token)
	if entry == null:
		return {"result": ERR_CANT_CONNECT}
	var client := entry.client
	entry.busy = true
	if token != null and token.cancelled:
		entry.busy = false
		return {"result": ERR_CANCELED}
	var result := await _perform_request_raw(client, method, path, headers, body, timeout_sec, token)
	entry.busy = false
	entry.last_used_ms = Time.get_ticks_msec()
	return result


func _acquire_connection(host: String, port: int, use_tls: bool, timeout_sec: float, token: CancelToken = null) -> ConnectionEntry:
	var key := _pool_key(host, port, use_tls)
	if not pools.has(key):
		pools[key] = []
	# try find idle
	for entry: ConnectionEntry in pools[key]:
		if not entry.busy:
			# Ensure still connected
			if entry.client.get_status() == HTTPClient.STATUS_CONNECTED:
				return entry
	# create new
	var client := HTTPClient.new()
	var tls_opts: TLSOptions = null
	if use_tls:
		tls_opts = TLSOptions.client()
	var err := client.connect_to_host(host, port, tls_opts)
	if err != OK:
		return null
	var start_ms := Time.get_ticks_msec()
	while true:
		client.poll()
		var status := client.get_status()
		if status == HTTPClient.STATUS_CONNECTED:
			break
		if token != null and token.cancelled:
			return null
		if float(Time.get_ticks_msec() - start_ms) / 1000.0 > timeout_sec:
			return null
		await _process_frame()
	var entry := ConnectionEntry.new(client, host, port, use_tls)
	pools[key].append(entry)
	return entry


func _perform_request_str(client: HTTPClient, method: int, path: String, headers: PackedStringArray, body: String, timeout_sec: float, token: CancelToken = null, progress_cb: Callable = Callable()) -> Dictionary:
	var req_err := client.request(method, path, headers, body)
	if req_err != OK:
		return {"result": req_err}
	var start_ms := Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if token != null and token.cancelled:
			return {"result": ERR_CANCELED}
		if float(Time.get_ticks_msec() - start_ms) / 1000.0 > timeout_sec:
			return {"result": ERR_TIMEOUT}
		await _process_frame()
	# read headers
	var code := client.get_response_code()
	var hdr_dict := client.get_response_headers_as_dictionary()
	var raw_headers: PackedStringArray = PackedStringArray()
	for k in hdr_dict.keys():
		raw_headers.append(String(k) + ": " + String(hdr_dict[k]))
	var content_length := int(hdr_dict.get("content-length", "0"))
	if progress_cb.is_valid():
		progress_cb.call(true, content_length, 0)
	# read body
	var body_bytes := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		if token != null and token.cancelled:
			return {"result": ERR_CANCELED}
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			body_bytes.append_array(chunk)
			if progress_cb.is_valid():
				progress_cb.call(false, content_length, body_bytes.size())
		else:
			await _process_frame()
	return {
		"result": OK,
		"code": code,
		"headers": raw_headers,
		"body": body_bytes,
	}


func _perform_request_raw(client: HTTPClient, method: int, path: String, headers: PackedStringArray, body: PackedByteArray, timeout_sec: float, token: CancelToken = null, progress_cb: Callable = Callable()) -> Dictionary:
	var req_err := client.request_raw(method, path, headers, body)
	if req_err != OK:
		return {"result": req_err}
	var start_ms := Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		if token != null and token.cancelled:
			return {"result": ERR_CANCELED}
		if float(Time.get_ticks_msec() - start_ms) / 1000.0 > timeout_sec:
			return {"result": ERR_TIMEOUT}
		await _process_frame()
	# read headers
	var code := client.get_response_code()
	var hdr_dict := client.get_response_headers_as_dictionary()
	var raw_headers: PackedStringArray = PackedStringArray()
	for k in hdr_dict.keys():
		raw_headers.append(String(k) + ": " + String(hdr_dict[k]))
	var content_length := int(hdr_dict.get("content-length", "0"))
	if progress_cb.is_valid():
		progress_cb.call(true, content_length, 0)
	# read body
	var body_bytes := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		if token != null and token.cancelled:
			return {"result": ERR_CANCELED}
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			body_bytes.append_array(chunk)
			if progress_cb.is_valid():
				progress_cb.call(false, content_length, body_bytes.size())
		else:
			await _process_frame()
	return {
		"result": OK,
		"code": code,
		"headers": raw_headers,
		"body": body_bytes,
	}


func _pool_key(host: String, port: int, use_tls: bool) -> String:
	var scheme := "https" if use_tls else "http"
	return scheme + "://" + host + ":" + str(port)


func _parse_url(url: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("^(https?)://([^/:]+)(?::(\\d+))?(/.*)?$")
	var m := re.search(url)
	if m == null:
		return {}
	var scheme := m.get_string(1)
	var host := m.get_string(2)
	var port_str := m.get_string(3)
	var path := m.get_string(4)
	var use_tls := scheme == "https"
	var default_port := 443 if use_tls else 80
	var port := default_port if port_str.is_empty() else int(port_str)
	if path.is_empty():
		path = "/"
	return {"scheme": scheme, "host": host, "port": port, "path": path, "tls": use_tls}


func _process_frame() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		await tree.process_frame

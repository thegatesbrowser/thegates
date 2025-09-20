extends Node
# class_name FileDownloader

signal progress(url: String, body_size: int, downloaded_bytes: int)

class DownloadRequest:
	var save_path: String
	var part_save_path: String
	var http: HTTPRequestPooled
	var timer: Timer
	var session: DownloadSession
	
	func _init(_save_path: String, _part_save_path: String, _http: HTTPRequestPooled, _timer: Timer, _session: DownloadSession = null) -> void:
		save_path = _save_path
		part_save_path = _part_save_path
		http = _http
		timer = _timer
		session = _session

class DownloadSession:
	var id: int
	var requests: Array[DownloadRequest] = []

	func _init(_id: int) -> void:
		id = _id

const DOWNLOAD_FOLDER := "user://gates_data"
const PROGRESS_DELAY := 0.1

var cache: HTTPCache
var download_requests: Array[DownloadRequest]
var next_session_id: int = 1
var recent_validated_ms_by_path: Dictionary = {}
const RECENT_VALIDATION_WINDOW_MS: int = 3000


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DOWNLOAD_FOLDER)
	cache = HTTPCache.new(DOWNLOAD_FOLDER)


func create_session() -> DownloadSession:
	var session := DownloadSession.new(next_session_id)
	next_session_id += 1
	return session


func cancel_session(session: DownloadSession) -> void:
	if session == null: return
	
	var to_cancel: Array[DownloadRequest] = session.requests.duplicate()
	for request in to_cancel:
		if request == null: continue
		
		request.http.cancel_request()
		request.http.queue_free()
		request.timer.queue_free()
		
		DirAccess.remove_absolute(request.part_save_path)
		
		download_requests.erase(request)
		session.requests.erase(request)


func is_cached(url: String) -> bool:
	var save_path = DOWNLOAD_FOLDER + "/" + url.md5_text() + "." + url.get_file().get_extension()
	for request in download_requests:
		if request.save_path == save_path:
			return false
	
	return FileAccess.file_exists(save_path)


func get_cached_path(url: String) -> String:
	var save_path := DOWNLOAD_FOLDER + "/" + url.md5_text() + "." + url.get_file().get_extension()
	if FileAccess.file_exists(save_path):
		return save_path
	return ""


func download(url: String, timeout: float = 0, force_revalidate: bool = false, session: DownloadSession = null) -> String:
	if url.is_empty(): return ""
	var save_path = DOWNLOAD_FOLDER + "/" + url.md5_text() + "." + url.get_file().get_extension()
	
	if has_request(save_path):
		await request_completed(save_path)
	
	var file_exists := FileAccess.file_exists(save_path)
	if file_exists and not force_revalidate and (cache.is_fresh(save_path) or was_recently_validated(save_path)):
		if cache.is_fresh(save_path):
			var mins_left: int = cache.get_minutes_until_expiry(save_path)
			Debug.logclr("Cache fresh for URL: " + url + ", expires in ~" + str(mins_left) + " min", Color.DIM_GRAY)
		return save_path
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	
	var headers: PackedStringArray = cache.build_conditional_headers(save_path, file_exists, force_revalidate)
	
	var result = await create_request(url, save_path, timeout, headers, session)
	if result == 200 or result == 304:
		return save_path
	else:
		if file_exists:
			return save_path
		DirAccess.remove_absolute(save_path)
		return ""


func download_with_status(url: String, timeout: float = 0, force_revalidate: bool = false, session: DownloadSession = null) -> Dictionary:
	# Returns { "path": String, "status": int }. If not forced and cache is fresh/recent,
	# skips network and returns the cached path with status 0.
	var result: Dictionary = {"path": "", "status": 0}
	if url.is_empty():
		return result
	var save_path := DOWNLOAD_FOLDER + "/" + url.md5_text() + "." + url.get_file().get_extension()
	
	if has_request(save_path):
		await request_completed(save_path)
	
	var file_exists: bool = FileAccess.file_exists(save_path)
	# Early return if cache is fresh or was very recently validated and not forcing revalidation
	if file_exists and not force_revalidate and (cache.is_fresh(save_path) or was_recently_validated(save_path)):
		if cache.is_fresh(save_path):
			var mins_left: int = cache.get_minutes_until_expiry(save_path)
			Debug.logclr("Cache fresh for URL: " + url + ", expires in ~" + str(mins_left) + " min", Color.DIM_GRAY)
		result["path"] = save_path
		result["status"] = 0
		return result
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	
	var headers: PackedStringArray = cache.build_conditional_headers(save_path, file_exists, force_revalidate)
	var code := await create_request(url, save_path, timeout, headers, session)
	result["status"] = code
	if code == 200 or code == 304:
		result["path"] = save_path
		return result
	else:
		if file_exists:
			result["path"] = save_path
			return result
		DirAccess.remove_absolute(save_path)
		return result


# Returns directory where file was downloaded. Keeps filename
func download_shared_lib(url: String, gate_url: String, force_revalidate: bool = false, session: DownloadSession = null) -> String:
	if url.is_empty(): return ""
	var dir = DOWNLOAD_FOLDER + "/" + gate_url.md5_text()
	var save_path = dir + "/" + url.get_file()
	
	if has_request(save_path):
		await request_completed(save_path)
	
	var file_exists := FileAccess.file_exists(save_path)
	if file_exists and not force_revalidate and (cache.is_fresh(save_path) or was_recently_validated(save_path)):
		if cache.is_fresh(save_path):
			var mins_left: int = cache.get_minutes_until_expiry(save_path)
			Debug.logclr("Cache fresh for URL: " + url + ", expires in ~" + str(mins_left) + " min", Color.DIM_GRAY)
		return dir
	DirAccess.make_dir_recursive_absolute(dir)
	
	var headers: PackedStringArray = cache.build_conditional_headers(save_path, file_exists, force_revalidate)
	
	var result = await create_request(url, save_path, 0, headers, session)
	if result == 200 or result == 304:
		return dir
	else:
		if file_exists:
			return dir
		DirAccess.remove_absolute(save_path)
		return ""


func has_request(save_path: String) -> bool:
	return download_requests.any(func(request: DownloadRequest): return request.save_path == save_path)


func request_completed(save_path: String) -> void:
	for request in download_requests:
		if request.save_path == save_path:
			await request.http.request_completed


func create_request(url: String, save_path: String, timeout: float = 0, headers: PackedStringArray = PackedStringArray(), session: DownloadSession = null) -> int:
	Debug.logclr("Downloading " + url + (" [session=" + str(session.id) + "]" if session != null else ""), Color.DIM_GRAY)
	var http = HTTPRequestPooled.new()
	# Download into a temporary file first, and promote to final path only on success
	var part_path: String = save_path + ".part"
	http.download_file = part_path
	http.timeout = timeout
	http.use_threads = true
	add_child(http)
	
	var timer = create_progress_emitter(url, http)
	var download_request = DownloadRequest.new(save_path, part_path, http, timer, session)
	download_requests.append(download_request)
	if session != null:
		session.requests.append(download_request)
	
	var start_ms: int = Time.get_ticks_msec()
	var err = http.request(url, headers)
	if err != OK: return err
	
	var completed = await http.request_completed
	var code: int = completed[1]
	var response_headers: PackedStringArray = completed[2]
	
	progress.emit(url, http.get_body_size(), http.get_downloaded_bytes())
	
	timer.queue_free()
	http.queue_free()
	download_requests.erase(download_request)
	if session != null: session.requests.erase(download_request)
	
	if code == 200 or code == 304:
		cache.update_from_response(save_path, url, response_headers, code)
		recent_validated_ms_by_path[save_path] = Time.get_ticks_msec()
	
	if code == 200: DirAccess.rename_absolute(part_path, save_path)
	DirAccess.remove_absolute(part_path)
	
	Debug.logclr("Downloaded " + url + " code=" + str(code) + " duration_ms=" + str(Time.get_ticks_msec() - start_ms), Color.DIM_GRAY)
	return code


func create_progress_emitter(url: String, http: HTTPRequestPooled) -> Timer:
	var timer = Timer.new()
	add_child(timer)
	
	var progress_emit = func():
		progress.emit(url, http.get_body_size(), http.get_downloaded_bytes())
	timer.timeout.connect(progress_emit)
	timer.start(PROGRESS_DELAY)
	
	return timer


func stop_all() -> void:
	for request in download_requests:
		request.http.cancel_request()
		request.http.queue_free()
		request.timer.queue_free()
		
		DirAccess.remove_absolute(request.part_save_path)
	
	download_requests.clear()


func was_recently_validated(save_path: String) -> bool:
	var last_ms: int = int(recent_validated_ms_by_path.get(save_path, 0))
	if last_ms == 0:
		return false
	return Time.get_ticks_msec() - last_ms <= RECENT_VALIDATION_WINDOW_MS


func _exit_tree() -> void:
	stop_all()

# TODO: cleanup ai generated code

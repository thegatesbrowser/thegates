extends Node
# class_name FileDownloader

signal progress(url: String, body_size: int, downloaded_bytes: int)

class DownloadRequest:
	var save_path: String
	var http: HttpClientRequest
	var timer: Timer
	
	func _init(_save_path: String, _http: HttpClientRequest, _timer: Timer) -> void:
		save_path = _save_path
		http = _http
		timer = _timer

const DOWNLOAD_FOLDER := "user://gates_data"
const PROGRESS_DELAY := 0.1

var cache: HttpCache
var download_requests: Array[DownloadRequest]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DOWNLOAD_FOLDER)
	cache = HttpCache.new(DOWNLOAD_FOLDER)


func is_cached(url: String) -> bool:
	var save_path = DOWNLOAD_FOLDER + "/" + url.md5_text() + "." + url.get_file().get_extension()
	for request in download_requests:
		if request.save_path == save_path:
			return false
	
	return FileAccess.file_exists(save_path)


func download(url: String, timeout: float = 0, force_revalidate: bool = false) -> String:
	if url.is_empty(): return ""
	var save_path = DOWNLOAD_FOLDER + "/" + url.md5_text() + "." + url.get_file().get_extension()
	
	if has_request(save_path):
		await request_completed(save_path)
	
	var was_cached := FileAccess.file_exists(save_path)
	if was_cached and not force_revalidate and cache.is_fresh(save_path):
		await get_tree().process_frame
		return save_path
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	
	var headers: PackedStringArray = cache.build_conditional_headers(save_path, force_revalidate)
	
	var result = await create_request(url, save_path, timeout, headers)
	if result == 200 or result == 304:
		return save_path
	else:
		if was_cached:
			return save_path
		DirAccess.remove_absolute(save_path)
		return ""


# Returns directory where file was downloaded. Keeps filename
func download_shared_lib(url: String, gate_url: String, force_revalidate: bool = false) -> String:
	if url.is_empty(): return ""
	var dir = DOWNLOAD_FOLDER + "/" + gate_url.md5_text()
	var save_path = dir + "/" + url.get_file()
	
	if has_request(save_path):
		await request_completed(save_path)
	
	var was_cached := FileAccess.file_exists(save_path)
	if was_cached and not force_revalidate and cache.is_fresh(save_path):
		await get_tree().process_frame
		return dir
	DirAccess.make_dir_recursive_absolute(dir)
	
	var headers: PackedStringArray = cache.build_conditional_headers(save_path, force_revalidate)
	
	var result = await create_request(url, save_path, 0, headers)
	if result == 200 or result == 304:
		return dir
	else:
		if was_cached:
			return dir
		DirAccess.remove_absolute(save_path)
		return ""


func has_request(save_path: String) -> bool:
	return download_requests.any(func(request: DownloadRequest): return request.save_path == save_path)


func request_completed(save_path: String) -> void:
	for request in download_requests:
		if request.save_path == save_path:
			await request.http.request_completed


func create_request(url: String, save_path: String, timeout: float = 0, headers: PackedStringArray = PackedStringArray()) -> int:
	var http = HttpClientRequest.new()
	http.download_file = save_path
	http.timeout = timeout
	http.use_threads = true
	
	var timer = create_progress_emitter(url, http)
	var download_request = DownloadRequest.new(save_path, http, timer)
	download_requests.append(download_request)
	
	Debug.logclr("Downloading " + url, Color.GRAY)
	var err = http.request(url, headers)
	if err != OK: return err
	var completed = await http.request_completed
	var code: int = completed[1]
	var response_headers: PackedStringArray = completed[2]
	
	progress.emit(url, http.get_body_size(), http.get_downloaded_bytes())
	timer.stop()
	remove_child(timer)
	download_requests.erase(download_request)
	
	if code == 200 or code == 304:
		cache.update_from_response(save_path, url, response_headers, code)
	
	return code


func create_progress_emitter(url: String, http: HttpClientRequest) -> Timer:
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
		
		request.timer.stop()
		remove_child(request.timer)
		
		DirAccess.remove_absolute(request.save_path)
	
	download_requests.clear()


func _exit_tree() -> void:
	FileDownloader.stop_all()

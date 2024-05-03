extends Node

class DownloadRequest:
	var save_path: String
	var http: HTTPRequest
	var timer: Timer
	
	func _init(_save_path: String, _http: HTTPRequest, _timer: Timer) -> void:
		save_path = _save_path
		http = _http
		timer = _timer

const DOWNLOAD_FOLDER := "user://gates_data"
const PROGRESS_DELAY := 0.3

signal progress(url: String, body_size: int, downloaded_bytes: int)

var download_requests: Array[DownloadRequest]


func _ready() -> void:
	FileTools.remove_recursive(DOWNLOAD_FOLDER)


func is_cached(url: String) -> bool:
	var save_path = DOWNLOAD_FOLDER + "/" + url.md5_text() + "." + url.get_file().get_extension()
	return FileAccess.file_exists(save_path)


func download(url: String, timeout: float = 0) -> String:
	var save_path = DOWNLOAD_FOLDER + "/" + url.md5_text() + "." + url.get_file().get_extension()
	
	if FileAccess.file_exists(save_path):
		await get_tree().process_frame
		return save_path
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	
	var result = await create_request(url, save_path, timeout)
	if result == 200:
		return save_path
	else:
		DirAccess.remove_absolute(save_path)
		return ""


# Returns directory where file was downloaded. Keeps filename
func download_shared_lib(url: String, gate_url: String) -> String:
	var dir = DOWNLOAD_FOLDER + "/" + gate_url.md5_text()
	var save_path = dir + "/" + url.get_file()
	
	if FileAccess.file_exists(save_path):
		await get_tree().process_frame
		return dir
	DirAccess.make_dir_recursive_absolute(dir)
	
	var result = await create_request(url, save_path)
	if result == 200:
		return dir
	else:
		DirAccess.remove_absolute(save_path)
		return ""


func create_request(url: String, save_path: String, timeout: float = 0) -> int:
	var http = HTTPRequest.new()
	http.download_file = save_path
	http.use_threads = true
	http.timeout = timeout
	add_child(http)
	
	var timer = create_progress_emitter(url, http)
	var download_request = DownloadRequest.new(save_path, http, timer)
	download_requests.append(download_request)
	
	var err = http.request(url)
	if err != OK: return err
	var code = (await http.request_completed)[1]
	
	progress.emit(url, http.get_body_size(), http.get_downloaded_bytes())
	timer.stop()
	remove_child(timer)
	remove_child(http)
	download_requests.erase(download_request)
	
	return code


func create_progress_emitter(url: String, http: HTTPRequest) -> Timer:
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
		remove_child(request.http)
		
		request.timer.stop()
		remove_child(request.timer)
		
		DirAccess.remove_absolute(request.save_path)
	
	download_requests.clear()


func _exit_tree() -> void:
	FileDownloader.stop_all()
	FileTools.remove_recursive(DOWNLOAD_FOLDER)

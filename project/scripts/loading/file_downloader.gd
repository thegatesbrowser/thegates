extends Node

signal progress(url: String, body_size: int, downloaded_bytes: int)

var folder: String = "user://gates_data"
var timer_speed := 0.3


func _ready() -> void:
	FileTools.remove_recursive(folder)


func download(url: String) -> String:
	var save_path = folder + "/" + url.md5_text() + "." + url.get_file().get_extension()
	if FileAccess.file_exists(save_path):
		await get_tree().process_frame
		return save_path
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	
	var http = HTTPRequest.new()
	http.use_threads = true
	add_child(http)
	
	http.download_file = save_path
	var err = http.request(url)
	if err != OK: return ""
	
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(print_percent.bind(url, http))
	timer.start(timer_speed)
	
	var res = await http.request_completed
	var code = res[1]
	
	print_percent(url, http)
	timer.stop()
	
	remove_child(timer)
	remove_child(http)
	
	return save_path if code == 200 else ""


func print_percent(url: String, http: HTTPRequest) -> void:
	progress.emit(url, http.get_body_size(), http.get_downloaded_bytes())


# Returns directory where file was downloaded. Keeps filename
func download_shared_lib(url: String, gate_url: String) -> String:
	var dir = folder + "/" + gate_url.md5_text()
	var save_path = dir + "/" + url.get_file()
	if FileAccess.file_exists(save_path):
		await get_tree().process_frame
		return dir
	DirAccess.make_dir_recursive_absolute(dir)
	
	var http = HTTPRequest.new()
	http.use_threads = true
	add_child(http)
	
	http.download_file = save_path
	var err = http.request(url)
	if err != OK: return ""
	
	var timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(print_percent.bind(url, http))
	timer.start(timer_speed)
	
	var res = await http.request_completed
	var code = res[1]
	
	print_percent(url, http)
	timer.stop()
	
	remove_child(timer)
	remove_child(http)
	
	if code == 200:
		return save_path
	else:
		DirAccess.remove_absolute(save_path)
		return ""


func stop_all() -> void:
	pass # TODO


func _exit_tree() -> void:
	FileTools.remove_recursive(folder)

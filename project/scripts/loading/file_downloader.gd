extends Node

var folder: String = "user://gates_data"


func _ready() -> void:
	FileTools.remove_recursive(folder)


func download(url: String) -> String:
	var save_path = folder + "/" + url.md5_text() + "." + url.get_file().get_extension()
	if FileAccess.file_exists(save_path):
		await get_tree().process_frame # TODO: remove workaround
		return save_path
	DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())
	
	var http = HTTPRequest.new()
	http.use_threads = true
	add_child(http)
	
	http.download_file = save_path
	var err = http.request(url)
	await http.request_completed
	
	remove_child(http)
	return save_path if err == OK else ""


func _exit_tree() -> void:
	FileTools.remove_recursive(folder)

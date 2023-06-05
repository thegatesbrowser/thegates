extends Resource
class_name SandboxExecutable

@export var linux: String
@export var linux_debug: String

@export var windows: String
@export var windows_debug: String

var path: String :
	get = get_executable_path


func get_executable_path() -> String:
	var executable_dir = OS.get_executable_path().get_base_dir() + "/"
	return executable_dir + get_filename()


func get_filename() -> String:
	if OS.is_debug_build():
		if OS.get_name() == "Windows": return windows_debug
		else: return linux_debug
	else:
		if OS.get_name() == "Windows": return windows
		else: return linux


func exists() -> bool:
	return FileAccess.file_exists(path)

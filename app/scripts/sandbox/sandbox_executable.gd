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
	var is_debug = Platform.is_debug()
	
	match Platform.get_platform():
		Platform.WINDOWS:
			return windows_debug if is_debug else windows
		Platform.LINUX_BSD:
			return linux_debug if is_debug else linux
		_:
			assert(false, "Platform is not supported")
			return ""


func exists() -> bool:
	return FileAccess.file_exists(path)

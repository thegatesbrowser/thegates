extends Resource
class_name RendererExecutable

@export var linux: String
@export var linux_debug: String

@export var windows: String
@export var windows_debug: String

@export var macos: String
@export var macos_debug: String

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
		Platform.MACOS:
			return macos_debug if is_debug else macos
		_:
			assert(false, "Platform is not supported")
			return ""


func exists() -> bool:
	return FileAccess.file_exists(path)

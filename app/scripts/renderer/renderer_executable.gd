extends Resource
class_name RendererExecutable

@export var api_settings: ApiSettings
@export var supported_godot_versions: Array[String]
@export var current_godot_version: String

@export var linux: String
@export var linux_debug: String

@export var windows: String
@export var windows_debug: String

@export var macos: String
@export var macos_framework: String
@export var macos_debug: String

var supported_platforms := [Platform.WINDOWS, Platform.LINUX_BSD, Platform.MACOS]


func download(godot_version: String, active_session: FileDownloader.DownloadSession) -> String:
	if godot_version not in supported_godot_versions:
		Debug.logclr("Renderer godot version %s is not supported" % [godot_version], Color.RED)
		return ""
	
	if Platform.get_platform() not in supported_platforms:
		Debug.logclr("Renderer platform %s is not supported" % [Platform.get_platform_string()], Color.RED)
		return ""
	
	var renderer_path = get_renderer_path(godot_version)
	if FileAccess.file_exists(renderer_path): return renderer_path
	Debug.logclr("Renderer executable not found at " + renderer_path, Color.YELLOW)
	
	var url = get_download_url(godot_version)
	var renderer_zip = await FileDownloader.download(url, 0.0, false, active_session)
	if renderer_zip.is_empty(): Debug.logclr("Failed to download renderer zip", Color.RED); return ""
	
	var extracted = UnZip.extract_renderer_files(renderer_zip, renderer_path)
	DirAccess.remove_absolute(renderer_zip)
	if not extracted: return ""
	
	return renderer_path


func get_download_url(godot_version: String) -> String:
	return api_settings.download_renderer % [Platform.get_platform_string(), godot_version]


func get_renderer_path(godot_version: String) -> String:
	match Platform.get_platform():
		Platform.WINDOWS:
			var use_debug = Platform.is_debug() and godot_version == current_godot_version
			var filename = windows_debug if use_debug else windows % [godot_version]
			return OS.get_executable_path().get_base_dir() + "/" + filename
			
		Platform.LINUX_BSD:
			var use_debug = Platform.is_debug() and godot_version == current_godot_version
			var filename = linux_debug if use_debug else linux % [godot_version]
			return OS.get_executable_path().get_base_dir() + "/" + filename
			
		Platform.MACOS:
			return get_renderer_path_macos(godot_version)
			
		_:
			assert(false, "Platform is not supported")
	
	return ""


func get_renderer_path_macos(godot_version: String) -> String:
	if not Platform.is_debug() and godot_version == current_godot_version:
		return OS.get_executable_path().get_base_dir() + "/" + macos_framework % [godot_version]
	
	if not Platform.is_debug() and godot_version != current_godot_version:
		return ProjectSettings.globalize_path("user://") + macos % [godot_version]
	
	if Platform.is_debug() and godot_version == current_godot_version:
		return OS.get_executable_path().get_base_dir() + "/" + macos_debug
	
	if Platform.is_debug() and godot_version != current_godot_version:
		return OS.get_executable_path().get_base_dir() + "/" + macos % [godot_version]
	
	return ""

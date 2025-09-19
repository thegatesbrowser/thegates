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
@export var macos_debug: String
@export var macos_debug_old: String

var supported_platforms := [Platform.WINDOWS, Platform.LINUX_BSD, Platform.MACOS]


func download(godot_version: String, active_session: FileDownloader.DownloadSession) -> String:
	if godot_version not in supported_godot_versions:
		Debug.logclr("Renderer godot version %s is not supported" % [godot_version], Color.RED)
		return ""
	
	if Platform.get_platform() not in supported_platforms:
		Debug.logclr("Renderer platform %s is not supported" % [Platform.get_platform_string()], Color.RED)
		return ""
	
	var renderer_path = get_renderer_path(godot_version)
	if FileAccess.file_exists(renderer_path):
		return renderer_path
	Debug.logclr("Renderer executable not found at " + renderer_path, Color.YELLOW)
	
	var url = get_download_url(godot_version)
	var renderer_zip = await FileDownloader.download(url, 0.0, false, active_session)
	
	if renderer_zip.is_empty(): Debug.logclr("Failed to download renderer zip", Color.RED); return ""
	
	var extracted = UnZip.extract_file(renderer_zip, renderer_path, true)
	DirAccess.remove_absolute(renderer_zip)
	if not extracted: return ""
	
	return renderer_path


func get_download_url(godot_version: String) -> String:
	return api_settings.download_renderer % [Platform.get_platform_string(), godot_version]


func get_renderer_path(godot_version: String) -> String:
	var use_debug = Platform.is_debug() and godot_version == current_godot_version
	var filename = ""
	
	match Platform.get_platform():
		Platform.WINDOWS:
			filename = windows_debug if use_debug else windows % [godot_version]
		Platform.LINUX_BSD:
			filename = linux_debug if use_debug else linux % [godot_version]
		Platform.MACOS:
			use_debug = Platform.is_debug()
			var current = godot_version == current_godot_version
			var debug_filename = macos_debug if current else macos_debug_old % [godot_version]
			filename = debug_filename if use_debug else macos % [godot_version]
		_:
			assert(false, "Platform is not supported")
	
	var executable_dir = OS.get_executable_path().get_base_dir() + "/"
	return executable_dir + filename

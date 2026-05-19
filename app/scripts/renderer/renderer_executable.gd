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
	if not need_download(renderer_path, godot_version): return renderer_path
	
	var url = get_download_url(godot_version)
	var renderer_result = await FileDownloader.download_with_status(url, 0.0, false, active_session)
	
	var status = renderer_result.get("status", 0)
	if status == 304 or status == 0:
		Debug.logclr("Renderer is already downloaded", Color.DIM_GRAY)
		return renderer_path
	elif status != 200:
		Debug.logclr("Failed to download renderer. Code: " + str(status), Color.RED)
		return ""
	
	var renderer_zip = renderer_result.get("path", "")
	var extracted = UnZip.extract_renderer_files(renderer_zip, renderer_path)
	if not extracted: return ""
	
	return renderer_path


func get_download_url(godot_version: String) -> String:
	return api_settings.download_renderer % [Platform.get_platform_string(), godot_version]


# Best-effort: 404 / network failure is logged and ignored — the gate boots
# without the shared cache, falling back to compile-from-source on first use.
func download_shader_cache(godot_version: String, active_session: FileDownloader.DownloadSession) -> void:
	if godot_version not in supported_godot_versions: return
	if Platform.get_platform() not in supported_platforms: return

	var renderer_path := get_renderer_path(godot_version)
	var target_dir := renderer_path + ".shader_cache"
	if DirAccess.dir_exists_absolute(target_dir): return

	var url := api_settings.download_shader_cache % [Platform.get_platform_string(), godot_version]
	var result: Dictionary = await FileDownloader.download_with_status(url, 0.0, false, active_session)

	var status: int = result.get("status", 0)
	if status != 200:
		Debug.logclr("Shader cache not downloaded (status=%d) for %s" % [status, godot_version], Color.DIM_GRAY)
		return

	var zip_path: String = result.get("path", "")
	if zip_path.is_empty():
		Debug.logclr("Shader cache download returned no path for %s" % [godot_version], Color.DIM_GRAY)
		return

	if not UnZip.extract_to_dir(zip_path, target_dir):
		Debug.logclr("Shader cache extraction failed for %s" % [godot_version], Color.DIM_GRAY)
		return

	Debug.logclr("Shader cache installed at %s" % [target_dir], Color.DIM_GRAY)


func get_renderer_path(godot_version: String) -> String:
	var dir = get_renderer_dir(godot_version)
	match Platform.get_platform():
		Platform.WINDOWS:
			return dir + get_renderer_filename(godot_version, windows, windows_debug)
			
		Platform.LINUX_BSD:
			return dir + get_renderer_filename(godot_version, linux, linux_debug)
			
		Platform.MACOS:
			return dir + get_renderer_filename(godot_version, macos, macos_debug)
			
		_:
			assert(false, "Platform is not supported")
	
	return ""


func get_renderer_filename(godot_version: String, release: String, debug: String) -> String:
	var is_current = godot_version == current_godot_version
	
	if Platform.is_debug() and is_current:
		return debug
	
	if is_current and Platform.is_macos():
		return macos_framework % [godot_version]
	
	return release % [godot_version]


func get_renderer_dir(godot_version: String) -> String:
	if godot_version != current_godot_version: return ProjectSettings.globalize_path("user://")
	else: return OS.get_executable_path().get_base_dir() + "/"


func need_download(renderer_path: String, godot_version: String) -> bool:
	var is_current = godot_version == current_godot_version
	
	if not is_current: # Always download old versions
		return true
	elif Platform.is_debug(): # Never download debug builds
		return false
	else:
		return not FileAccess.file_exists(renderer_path)

extends Node

@export var renderer: RendererExecutable
@export var gate_events: GateEvents
@export var connect_timeout: float
@export var speculative_prefetch: bool = true

var gate: Gate

# Speculative prefetch session
var prefetch_session: FileDownloader.DownloadSession
var prefetch_cached_gate: ConfigGate

# Active download session for this gate load
var active_session: FileDownloader.DownloadSession
var config_session: FileDownloader.DownloadSession

# For parallel downloading
var has_errors: bool
var load_resources_done: bool
var renderer_ready: bool
var shared_libs_count: int = -1
var shared_libs_done: int

# Show progress when resource pack is started loading
var resource_pack_url: String
var resource_pack_started_loading: bool


func _ready() -> void:
	FileDownloader.progress.connect(on_progress)
	load_gate(gate_events.current_gate_url)


func load_gate(gate_url: String) -> void:
	Debug.logclr("======== " + gate_url + " ========", Color.GREEN)
	var config_url = gate_url.split("?")[0]
	
	# 1) Start config revalidation immediately (fire-and-forget) within its own session
	config_session = FileDownloader.create_session()
	var config_state = FileDownloader.call("download_with_status", config_url, connect_timeout, false, config_session)
	
	# 2) Start speculative prefetch using cached config (if available)
	prefetch_session = null
	var cached_config_path := FileDownloader.get_cached_path(config_url)
	if not cached_config_path.is_empty():
		var cached_gate := ConfigGate.new(cached_config_path, config_url)
		if cached_gate.load_result == OK:
			prefetch_cached_gate = cached_gate
			prefetch_session = prefetch_assets(cached_gate, config_url)
	
	# 3) Await config revalidation while prefetch is in-flight
	var cfg_result: Dictionary = await config_state
	var config_path: String = cfg_result.get("path", "")
	var cfg_status: int = int(cfg_result.get("status", 0))
	if config_path.is_empty():
		FileDownloader.cancel_session(prefetch_session)
		return error(GateEvents.GateError.NOT_FOUND)
	
	var c_gate = ConfigGate.new(config_path, config_url)
	if c_gate.load_result != OK:
		FileDownloader.cancel_session(prefetch_session)
		return error(GateEvents.GateError.INVALID_CONFIG)
	gate_events.gate_config_loaded_emit(config_url, c_gate)
	
	gate = Gate.create(gate_url, c_gate.title, c_gate.description, c_gate.icon_url, c_gate.image_url)
	gate_events.gate_info_loaded_emit(gate)
	
	# If config changed, cancel speculative prefetch and start correct requests
	if prefetch_session != null:
		var unchanged: bool = false
		if prefetch_cached_gate != null:
			unchanged = are_configs_equivalent(prefetch_cached_gate, c_gate)
		else:
			unchanged = (cfg_status == 304)
		if not unchanged:
			FileDownloader.cancel_session(prefetch_session)
			prefetch_session = null
	
	# 3) Download all in parallel within a dedicated session.
	#    If prefetch was kept, these will await in-flight requests based on save_path reuse.
	active_session = FileDownloader.create_session()
	load_icon(c_gate)
	load_image(c_gate)
	load_resources(c_gate)
	load_shared_libs(c_gate, config_url)
	load_renderer(c_gate)


func prefetch_assets(c_gate: ConfigGate, config_url: String):
	# Fire-and-forget speculative requests using a session. They will be reused later
	var session = FileDownloader.create_session()
	if not c_gate.icon_url.is_empty():
		FileDownloader.download(c_gate.icon_url, 0.0, false, session)
	if not c_gate.image_url.is_empty():
		FileDownloader.download(c_gate.image_url, 0.0, false, session)
	if not c_gate.resource_pack_url.is_empty():
		FileDownloader.download(c_gate.resource_pack_url, 0.0, false, session)
	for lib in c_gate.libraries:
		FileDownloader.download_shared_lib(lib, config_url, false, session)
	return session


func are_configs_equivalent(a: ConfigGate, b: ConfigGate) -> bool:
	if a == null or b == null:
		return false
	if a.icon_url != b.icon_url: return false
	if a.image_url != b.image_url: return false
	if a.resource_pack_url != b.resource_pack_url: return false
	if a.libraries.size() != b.libraries.size(): return false
	for i in a.libraries.size():
		if a.libraries[i] != b.libraries[i]:
			return false
	return true


func load_icon(c_gate: ConfigGate) -> void:
	gate.icon = await FileDownloader.download(c_gate.icon_url, 0.0, false, active_session)
	gate_events.gate_icon_loaded_emit(gate)
	# Finish without icon


func load_image(c_gate: ConfigGate) -> void:
	gate.image = await FileDownloader.download(c_gate.image_url, 0.0, false, active_session)
	gate_events.gate_image_loaded_emit(gate)
	# Finish without image


func load_resources(c_gate: ConfigGate) -> void:
	resource_pack_url = c_gate.resource_pack_url
	gate.resource_pack = await FileDownloader.download(c_gate.resource_pack_url, 0.0, false, active_session)
	if gate.resource_pack.is_empty(): return error(GateEvents.GateError.MISSING_PACK)
	
	load_resources_done = true
	try_finish_loading()


func load_shared_libs(c_gate: ConfigGate, config_url: String) -> void:
	Debug.logclr("GDExtension libraries: " + str(c_gate.libraries), Color.DIM_GRAY)
	shared_libs_count = c_gate.libraries.size()
	for lib in c_gate.libraries:
		load_lib(config_url, lib)
	
	try_finish_loading() # In case of 0 libs


func load_lib(config_url: String, lib: String) -> void:
	gate.shared_libs_dir = await FileDownloader.download_shared_lib(lib, config_url, false, active_session)
	if gate.shared_libs_dir.is_empty(): return error(GateEvents.GateError.MISSING_LIBS)
	
	shared_libs_done += 1
	try_finish_loading()


func load_renderer(c_gate: ConfigGate) -> void:
	gate.renderer = await renderer.download(c_gate.godot_version, active_session)
	if gate.renderer.is_empty(): return error(GateEvents.GateError.MISSING_RENDERER)
	
	renderer_ready = true
	try_finish_loading()


func try_finish_loading() -> void:
	if has_errors: return
	if not load_resources_done: return
	if not renderer_ready: return
	if shared_libs_count == -1 or shared_libs_done != shared_libs_count: return
	
	gate_events.gate_loaded_emit(gate)


func error(code: GateEvents.GateError) -> void:
	Debug.logerr("GateError: " + GateEvents.GateError.keys()[code])
	has_errors = true
	gate_events.gate_error_emit(code)


func on_progress(url: String, body_size: int, downloaded_bytes: int) -> void:
	if url == resource_pack_url and not resource_pack_started_loading and body_size > 0:
		resource_pack_started_loading = true
	
	if not resource_pack_started_loading:
		return
	
	gate_events.download_progress_emit(url, body_size, downloaded_bytes)


func _exit_tree() -> void:
	FileDownloader.progress.disconnect(on_progress)
	FileDownloader.cancel_session(prefetch_session)
	FileDownloader.cancel_session(config_session)
	FileDownloader.cancel_session(active_session)

# TODO: cleanup ai generated code

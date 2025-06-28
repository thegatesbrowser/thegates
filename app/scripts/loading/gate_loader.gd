extends Node

@export var gate_events: GateEvents
@export var connect_timeout: float

var gate: Gate

# For parallel downloading
var has_errors: bool
var load_resources_done: bool
var shared_libs_count: int = -1
var shared_libs_done: int

# Show progress when resource pack is started loading
var resource_pack_url: String
var resource_pack_started_loading: bool


func _ready() -> void:
	FileDownloader.progress.connect(on_progress)
	load_gate(gate_events.current_gate_url)


func load_gate(config_url: String) -> void:
	Debug.logclr("======== " + config_url + " ========", Color.GREEN)
	var config_path = await FileDownloader.download(config_url, connect_timeout)
	if config_path.is_empty(): return error(GateEvents.GateError.NOT_FOUND)
	
	var c_gate = ConfigGate.new(config_path, config_url)
	if c_gate.load_result != OK: return error(GateEvents.GateError.INVALID_CONFIG)
	gate_events.gate_config_loaded_emit(config_url, c_gate)
	
	gate = Gate.create(config_url, c_gate.title, c_gate.description, "", "", "", "")
	gate_events.gate_info_loaded_emit(gate)
	
	# Download all in parallel
	load_icon(c_gate)
	load_image(c_gate)
	load_resources(c_gate)
	load_shared_libs(c_gate, config_url)


func load_icon(c_gate: ConfigGate) -> void:
	gate.icon = await FileDownloader.download(c_gate.icon_url)
	gate_events.gate_icon_loaded_emit(gate)
	# Finish without icon


func load_image(c_gate: ConfigGate) -> void:
	gate.image = await FileDownloader.download(c_gate.image_url)
	gate_events.gate_image_loaded_emit(gate)
	# Finish without image


func load_resources(c_gate: ConfigGate) -> void:
	resource_pack_url = c_gate.resource_pack_url
	gate.resource_pack = await FileDownloader.download(c_gate.resource_pack_url)
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
	gate.shared_libs_dir = await FileDownloader.download_shared_lib(lib, config_url)
	if gate.shared_libs_dir.is_empty(): return error(GateEvents.GateError.MISSING_LIBS)
	
	shared_libs_done += 1
	try_finish_loading()


func try_finish_loading() -> void:
	if has_errors: return
	if not load_resources_done: return
	if shared_libs_count == -1 or shared_libs_done != shared_libs_count: return
	
	gate_events.gate_loaded_emit(gate)


func error(code: GateEvents.GateError) -> void:
	Debug.logclr("GateError: " + GateEvents.GateError.keys()[code], Color.MAROON)
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
	FileDownloader.stop_all()

extends Node

@export var gate_events: GateEvents
@export var connect_timeout: float

var c_gate: ConfigGate


func _ready() -> void:
	FileDownloader.progress.connect(on_progress)
	load_gate(gate_events.current_gate_url)


func load_gate(config_url: String) -> void:
	Debug.logclr("======== " + config_url + " ========", Color.GREEN)
	var config_path = await FileDownloader.download(config_url, connect_timeout)
	if config_path.is_empty(): return error(GateEvents.GateError.NOT_FOUND)
	
	c_gate = ConfigGate.new(config_path, config_url)
	gate_events.gate_config_loaded_emit(config_url, c_gate)
	
	var image_path = await FileDownloader.download(c_gate.image_url)
	var gate = Gate.create(config_url, c_gate.title, c_gate.description, image_path, "", "")
	var is_cached = FileDownloader.is_cached(c_gate.resource_pack_url)
	gate_events.gate_info_loaded_emit(gate, is_cached)
	
	gate.resource_pack = await FileDownloader.download(c_gate.resource_pack_url)
	if gate.resource_pack.is_empty(): return error(GateEvents.GateError.MISSING_PACK)
	
	Debug.logclr("Downloading GDExtension libraries: " + str(c_gate.libraries), Color.DIM_GRAY)
	for lib in c_gate.libraries:
		gate.shared_libs_dir = await FileDownloader.download_shared_lib(lib, config_url)
		if gate.shared_libs_dir.is_empty(): return error(GateEvents.GateError.MISSING_LIBS)
	
	gate_events.gate_loaded_emit(gate)


func error(code: GateEvents.GateError) -> void:
	Debug.logclr("GateError: " + GateEvents.GateError.keys()[code], Color.MAROON)
	gate_events.gate_error_emit(code)


func on_progress(url: String, body_size: int, downloaded_bytes: int) -> void:
	gate_events.download_progress_emit(url, body_size, downloaded_bytes)


func _exit_tree() -> void:
	FileDownloader.progress.disconnect(on_progress)
	FileDownloader.stop_all()

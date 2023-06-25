extends Node

@export var gate_events: GateEvents

var c_gate: ConfigGate


func _ready() -> void:
	load_gate(gate_events.current_gate_url)


func load_gate(config_url: String) -> void:
	Debug.logclr("======== " + config_url + " ========", Color.GREEN)
	var config_path: String = await FileDownloader.download(config_url)
	c_gate = ConfigGate.new(config_path, config_url)
	
	var image_path = await FileDownloader.download(c_gate.image_url)
	var gate = Gate.create(config_url, c_gate.title, c_gate.description, image_path, "", "")
	gate_events.gate_info_loaded_emit(gate)
	
	gate.resource_pack = await FileDownloader.download(c_gate.resource_pack_url)
	
	Debug.logclr("Downloading GDExtension libraries: " + str(c_gate.libraries), Color.DIM_GRAY)
	for lib in c_gate.libraries:
		gate.shared_libs_dir = await FileDownloader.download_shared_lib(lib, config_url)
	
	gate_events.gate_loaded_emit(gate)

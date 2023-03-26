extends Node

@export var gate_events: GateEvents

var c_gate: ConfigGate


func _ready() -> void:
	load_gate(gate_events.current_gate_url)


func load_gate(config_url: String) -> void:
	config_url = Url.fix_gate_url(config_url)
	
	Debug.logr("======== " + config_url + " ========")
	var config_path: String = await FileDownloader.download(config_url)
	c_gate = ConfigGate.new(config_path, config_url)
	
	var image_path = await FileDownloader.download(c_gate.image_url)
	var gate = Gate.create(config_url, c_gate.title, c_gate.description,
		image_path, "", "", "")
	gate_events.gate_info_loaded_emit(gate)
	
	gate.godot_config = await FileDownloader.download(c_gate.godot_config_url)
	gate.global_script_class = await FileDownloader.download(c_gate.global_script_class_url)
	gate.resource_pack = await FileDownloader.download(c_gate.resource_pack_url)
	gate_events.gate_loaded_emit(gate)

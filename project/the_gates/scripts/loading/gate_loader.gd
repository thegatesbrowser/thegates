extends Node

@export var gate_events: GateEvents

var g_config: GateConfig


func _ready() -> void:
	load_gate(gate_events.current_gate_url)


func load_gate(config_url: String) -> void:
	config_url = Url.fix_gate_url(config_url)
	
	Debug.logr("======== " + config_url + " ========")
	var config_path: String = await FileDownloader.download(config_url)
	g_config = GateConfig.new(config_path, config_url)
	
	var image_path = await FileDownloader.download(g_config.image_url)
	var gate = Gate.create(config_url, g_config.title, g_config.description,
		image_path, "", "")
	gate_events.gate_info_loaded_emit(gate)
	
	gate.godot_config = await FileDownloader.download(g_config.godot_config_url)
	gate.resource_pack = await FileDownloader.download(g_config.resource_pack_url)
	gate_events.gate_loaded_emit(gate)

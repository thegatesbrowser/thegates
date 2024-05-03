extends Node

@export var api: ApiSettings
@export var gate_events: GateEvents


func _ready() -> void:
	gate_events.gate_config_loaded.connect(send_discover_gate)


func send_discover_gate(c_url: String, c_gate: ConfigGate) -> void:
	var body = {}
	body.url = c_url
	body.title = c_gate.title
	body.description = c_gate.description
	body.image = c_gate.image_url
	body.resource_pack = c_gate.resource_pack_url
	body.libraries = c_gate.libraries
	
	var url = api.discover_gate
	var callback = func(_result, code, _headers, _body):
		if code != 200: Debug.logclr("Request send_discover_gate failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback, body, HTTPClient.METHOD_POST)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request send_discover_gate", Color.RED)

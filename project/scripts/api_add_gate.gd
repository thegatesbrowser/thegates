extends Node

@export var backend: BackendSettings
@export var gate_events: GateEvents


func _ready() -> void:
	gate_events.open_gate.connect(send_add_gate)


func send_add_gate(gate_url: String) -> void:
	var url = backend.add_gate + gate_url.uri_encode()
	var callback = func(_result, code, _headers, _body):
		if code != 200: Debug.logclr("Request send_open_gate failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback, {}, HTTPClient.METHOD_POST)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request send_open_gate", Color.RED)

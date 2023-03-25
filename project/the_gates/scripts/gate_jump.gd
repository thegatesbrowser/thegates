extends Node

@export var gate_events: GateEvents

var gate_jump: String = "gate_jump"


func _ready() -> void:
	gate_events.gate_entered.connect(connect_to_gate_signals)


func connect_to_gate_signals() -> void:
	var root_node = get_child(0)
	if root_node == null: Debug.logerr("Gate root node is null"); return
	if root_node.has_signal(gate_jump):
		root_node.connect(gate_jump, on_gate_jump)


func on_gate_jump(url: String) -> void:
	url = Url.join(gate_events.current_gate_url, url)
	gate_events.open_gate_emit(url)

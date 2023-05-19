extends Node

@export var gate_events: GateEvents

var input_sync: InputSync

func _ready() -> void:
	gate_events.gate_entered.connect(start_server)


func start_server() -> void:
	input_sync = InputSync.new()
	input_sync.bind()


func _input(event: InputEvent) -> void:
	if input_sync == null: return
	input_sync.send_input_event(event)

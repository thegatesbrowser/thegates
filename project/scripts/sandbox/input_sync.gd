extends Node

@export var gate_events: GateEvents
@export var ui_events: UiEvents

var input_sync: InputSync
var should_send := false


func _ready() -> void:
	gate_events.gate_entered.connect(start_server)
	ui_events.visibility_changed.connect(on_ui_visibility_changed)


func start_server() -> void:
	input_sync = InputSync.new()
	input_sync.bind()


func on_ui_visibility_changed(visible: bool) -> void:
	should_send = not visible


func _input(event: InputEvent) -> void:
	if input_sync == null or not should_send: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: return
	
	input_sync.send_input_event(event)

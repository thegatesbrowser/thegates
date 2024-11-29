extends Node

@export var gate_events: GateEvents
@export var ui_events: UiEvents
@export var render_result: RenderResult

var scale: float
var offset: Vector2

var input_sync: InputSync
var should_send := false


func _ready() -> void:
	gate_events.gate_entered.connect(start_server)
	ui_events.ui_mode_changed.connect(on_ui_mode_changed)


func start_server() -> void:
	input_sync = InputSync.new()
	input_sync.bind()
	
	scale = DisplayServer.screen_get_scale()
	offset = render_result.global_position
	Debug.logclr("Mouse position scale: %.2f. Offset: %.2f" % [scale, offset.y], Color.DIM_GRAY)


func on_ui_mode_changed(mode: UiEvents.UiMode) -> void:
	should_send = mode == UiEvents.UiMode.FULL_SCREEN


func _input(_event: InputEvent) -> void:
	if input_sync == null or not should_send: return
	
	var event = _event
	if event is InputEventMouse:
		event = _event.duplicate()
		event.position = get_scaled_mouse_pos(event.position)
		event.global_position = get_scaled_mouse_pos(event.global_position)
	
	input_sync.send_input_event(event)


func get_scaled_mouse_pos(position : Vector2) -> Vector2:
	return (position - offset) * scale


func _exit_tree() -> void:
	if input_sync != null:
		input_sync.close()
		input_sync = null

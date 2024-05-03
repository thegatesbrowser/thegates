extends Node

@export var gate_events: GateEvents
@export var ui_events: UiEvents
@export var render_result: RenderResult

var scale_width: float
var scale_height: float

var input_sync: InputSync
var should_send := false


func _ready() -> void:
	gate_events.gate_entered.connect(start_server)
	ui_events.ui_mode_changed.connect(on_ui_mode_changed)
	
	scale_width = float(render_result.width) / ui_events.current_ui_size.x
	scale_height = float(render_result.height) / ui_events.current_ui_size.y
	Debug.logclr("Mouse position scale: %.2fx%.2f" % [scale_width, scale_height], Color.DIM_GRAY)


func start_server() -> void:
	input_sync = InputSync.new()
	input_sync.bind()


func on_ui_mode_changed(mode: UiEvents.UiMode) -> void:
	should_send = mode == UiEvents.UiMode.FULL_SCREEN


func _input(event: InputEvent) -> void:
	if input_sync == null or not should_send: return
	
	if event is InputEventMouse:
		event.position = get_scaled_mouse_pos(event.position)
		event.global_position = get_scaled_mouse_pos(event.global_position)
	
	input_sync.send_input_event(event)


func get_scaled_mouse_pos(position : Vector2) -> Vector2:
	position.x *= scale_width
	position.y *= scale_height
	return position

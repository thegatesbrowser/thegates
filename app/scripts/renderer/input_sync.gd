extends Node

@export var gate_events: GateEvents
@export var ui_events: UiEvents
@export var render_result: RenderResult

var input_sync: InputSync
var should_send := false


func _ready() -> void:
	ui_events.ui_mode_changed.connect(on_ui_mode_changed)
	gate_events.call_or_subscribe(GateEvents.Early.ENTERED, start_server)


func start_server() -> void:
	input_sync = InputSync.new()
	input_sync.socket_bind()

	Debug.logclr("Render area %s for %dx%d" % [render_result.size, render_result.width, render_result.height], Color.DIM_GRAY)


func on_ui_mode_changed(mode: UiEvents.UiMode) -> void:
	should_send = mode == UiEvents.UiMode.FOCUSED
	if should_send: update_mouse_position()


func _input(_event: InputEvent) -> void:
	if input_sync == null or not should_send: return
	
	var event = _event
	if event is InputEventMouse:
		event = _event.duplicate()
		event.position = get_scaled_mouse_pos(event.position)
		event.global_position = get_scaled_mouse_pos(event.global_position)
	
	input_sync.send_input_event(event)


func update_mouse_position() -> void:
	var event = InputEventMouseMotion.new()
	var last_mouse_position = get_viewport().get_mouse_position()
	event.position = get_scaled_mouse_pos(last_mouse_position)
	event.global_position = get_scaled_mouse_pos(last_mouse_position)
	
	input_sync.send_input_event(event)


func get_scaled_mouse_pos(position: Vector2) -> Vector2:
	# RenderResult is STRETCH_KEEP_ASPECT_CENTERED: the gate's frame is scaled to
	# fit the node and centred, with bars where the aspects differ. The renderer
	# keeps rendering at the resolution it was spawned with, so input has to be
	# mapped from the current rect into that frame, letterbox included — a resize
	# moves and scales the rect, and a stale offset left clicks landing off.
	var rect: Rect2 = render_result.get_global_rect()
	var frame: Vector2 = Vector2(render_result.width, render_result.height)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or frame.x <= 0.0 or frame.y <= 0.0:
		return Vector2.ZERO

	var fit: float = minf(rect.size.x / frame.x, rect.size.y / frame.y)
	var drawn: Vector2 = frame * fit
	var origin: Vector2 = rect.position + (rect.size - drawn) * 0.5
	return (position - origin) / fit


func _exit_tree() -> void:
	if input_sync != null:
		input_sync.close()
		input_sync = null

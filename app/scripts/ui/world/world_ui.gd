extends Control

@export var ui_events: UiEvents
@export var gate_events: GateEvents
@export var command_events: CommandEvents
@export var render_result: RenderResult

var _visible: bool = true
var child_mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var mouse_in_window: bool = true
var window_focused: bool = true
var gate_started: bool


func _ready() -> void:
	command_events.set_mouse_mode.connect(set_child_mouse_mode)
	gate_events.first_frame.connect(on_first_frame)
	gate_events.not_responding.connect(on_not_responding)
	ui_events.debug_window_opened.connect(show_ui)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("show_ui") and not event.is_echo():
		if _visible:
			hide_ui()
		else:
			show_ui()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_IN:
			window_focused = true
			try_apply_child_mouse_mode()
			
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			window_focused = false
			
		NOTIFICATION_WM_MOUSE_ENTER:
			mouse_in_window = true
			
		NOTIFICATION_WM_MOUSE_EXIT:
			mouse_in_window = false


func set_child_mouse_mode(mode: int) -> void:
	child_mouse_mode = mode
	try_apply_child_mouse_mode()


func on_first_frame() -> void:
	gate_started = true
	hide_ui()


func on_not_responding() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func show_ui() -> void:
	if _visible: return
	_visible = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	ui_events.ui_mode_changed_emit(UiEvents.UiMode.INITIAL)
	render_result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func hide_ui() -> void:
	if not _visible: return
	if not gate_started: return
	if not is_app_in_focus(): return
	if ui_events.is_typing_search: return
	if ui_events.is_debug_window_opened: return
	
	_visible = false
	
	try_apply_child_mouse_mode()
	ui_events.ui_mode_changed_emit(UiEvents.UiMode.FOCUSED)
	render_result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func try_apply_child_mouse_mode() -> void:
	if _visible: return
	if not gate_started: return
	if not is_app_in_focus(): return
	
	Input.set_mouse_mode(child_mouse_mode)


func is_app_in_focus() -> bool:
	return window_focused and mouse_in_window

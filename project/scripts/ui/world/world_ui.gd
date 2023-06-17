extends Control

@export var ui_events: UiEvents
@export var gate_events: GateEvents
@export var command_events: CommandEvents

var mouse_mode: int = Input.MOUSE_MODE_VISIBLE
var _visible: bool = true


func _ready() -> void:
	gate_events.gate_entered.connect(hide_ui)
	command_events.set_mouse_mode.connect(set_mouse_mode)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func set_mouse_mode(mode: int) -> void:
	mouse_mode = mode
	if not _visible: Input.set_mouse_mode(mode)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("show_ui") and not event.is_echo():
		if _visible:
			hide_ui()
		else:
			show_ui()


func show_ui() -> void:
	if _visible: return
	_visible = true
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	ui_events.visibility_changed_emit(true)


func hide_ui() -> void:
	if not _visible: return
	_visible = false
	
	Input.set_mouse_mode(mouse_mode)
	ui_events.visibility_changed_emit(false)

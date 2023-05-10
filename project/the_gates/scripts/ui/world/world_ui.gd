extends Control

var mouse_mode: int = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hide_ui()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("show_ui") and not event.is_echo():
		if visible:
			hide_ui()
		else:
			show_ui()


func show_ui() -> void:
	visible = true
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_ui() -> void:
	visible = false
	if mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

extends Button
class_name RoundButton


func _ready() -> void:
	if disabled: disable()
	else: enable()
	
	button_up.connect(on_button_up)


func on_button_up() -> void:
	release_focus()


func disable() -> void:
	disabled = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW


func enable() -> void:
	disabled = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

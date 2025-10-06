extends NotificationBase
class_name NotificationMouse

@export var ui_events: UiEvents


func _ready() -> void:
	ui_events.mouse_mode_changed.connect(on_mouse_mode_changed)


func on_mouse_mode_changed(mode: int) -> void:
	if mode == Input.MOUSE_MODE_CAPTURED:
		show_notification()
	else:
		hide_notification()

extends Resource
class_name UiEvents

signal ui_visibility_changed(visible: bool)
signal ui_size_changed(size: Vector2)

var current_ui_size: Vector2


func ui_visibility_changed_emit(visible: bool) -> void:
	ui_visibility_changed.emit(visible)


func ui_size_changed_emit(size: Vector2) -> void:
	current_ui_size = size
	ui_size_changed.emit(size)

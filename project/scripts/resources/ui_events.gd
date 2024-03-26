extends Resource
class_name UiEvents

signal ui_mode_changed(mode: UiMode)
signal ui_size_changed(size: Vector2)

enum UiMode
{
	INITIAL,
	FULL_SCREEN
}

var current_ui_size: Vector2


func ui_mode_changed_emit(mode: UiMode) -> void:
	ui_mode_changed.emit(mode)


func ui_size_changed_emit(size: Vector2) -> void:
	current_ui_size = size
	ui_size_changed.emit(size)

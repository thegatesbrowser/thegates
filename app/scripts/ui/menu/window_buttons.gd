extends Control

@export var minimize: BaseButton
@export var maximize: BaseButton
@export var exit: BaseButton
@export var restored_window_ratio: float = 0.75


func _ready() -> void:
	minimize.pressed.connect(on_minimize)
	maximize.pressed.connect(on_maximize)
	exit.pressed.connect(on_exit)


func on_minimize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


func on_maximize() -> void:
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		restore_from_maximized()


func on_exit() -> void:
	get_tree().quit()


func restore_from_maximized() -> void:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var target_size: Vector2i = Vector2i(int(usable.size.x * restored_window_ratio), int(usable.size.y * restored_window_ratio))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(target_size)

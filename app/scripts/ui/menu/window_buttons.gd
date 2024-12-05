extends Control

@export var minimize: BaseButton
@export var maximize: BaseButton
@export var exit: BaseButton


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
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func on_exit() -> void:
	get_tree().quit()

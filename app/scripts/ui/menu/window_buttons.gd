extends Control

@export var minimize: BaseButton
@export var exit: BaseButton


func _ready() -> void:
	minimize.pressed.connect(on_minimize)
	exit.pressed.connect(on_exit)


func on_minimize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


func on_exit() -> void:
	get_tree().quit()

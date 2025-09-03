extends Node

@export var ui_events: UiEvents
@export var window: Window

var window_visible


func _ready() -> void:
	window_hide()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_debug") and not event.is_echo():
		if window_visible:
			window_hide()
		else:
			window_show()


func _on_window_window_input(event: InputEvent) -> void:
	_input(event)


func _on_window_close_requested() -> void:
	window_hide()


func _on_window_focus_exited() -> void:
	window_hide()


func window_show() -> void:
	window.show()
	window_visible = true
	ui_events.debug_window_opened_emit()


func window_hide() -> void:
	window.hide()
	window_visible = false
	ui_events.debug_window_closed_emit()

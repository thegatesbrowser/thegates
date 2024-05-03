extends Control

@export var ui_events: UiEvents


func _ready() -> void:
	resized.connect(on_resized)
	on_resized()


func on_resized() -> void:
	Debug.logclr("Ui resized: %dx%d" % [size.x, size.y], Debug.SILENT_CLR)
	ui_events.ui_size_changed_emit(size)

extends Control

@export var ui_events: UiEvents


func _ready() -> void:
	resized.connect(on_resized)
	set_initial_screen()
	on_resized()


func on_resized() -> void:
	Debug.logclr("Ui resized: %dx%d" % [size.x, size.y], Debug.SILENT_CLR)
	ui_events.ui_size_changed_emit(size)


func set_initial_screen() -> void:
	var last_screen = DataSaver.get_value("settings", "last_screen")
	if last_screen == null: last_screen = 0
	
	DisplayServer.window_set_current_screen(last_screen)
	Debug.logclr("Initial screen: %d" % [last_screen], Debug.SILENT_CLR)
	
	if Platform.is_macos():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		Debug.logclr("Setting fullscreen mode", Debug.SILENT_CLR)


func _exit_tree() -> void:
	var last_screen = DisplayServer.window_get_current_screen()
	DataSaver.set_value("settings", "last_screen", last_screen)

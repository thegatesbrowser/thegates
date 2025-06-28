extends Control

@export var ui_events: UiEvents

var window: Window


func _ready() -> void:
	window = get_window()
	
	window.dpi_changed.connect(scale_content)
	resized.connect(on_resized)
	
	set_initial_screen()
	scale_content()
	on_resized()


func on_resized() -> void:
	Debug.logclr("Ui resized: %dx%d" % [size.x, size.y], Debug.SILENT_CLR)
	ui_events.ui_size_changed_emit(size)


func scale_content() -> void:
	# TODO: support other platforms FEATURE_HIDPI
	var screen_scale = DisplayServer.screen_get_scale()
	get_window().content_scale_factor = screen_scale
	Debug.logclr("Content scale factor: %.2f" % [screen_scale], Debug.SILENT_CLR)


func set_initial_screen() -> void:
	var last_screen = DataSaver.get_value("settings", "last_screen", 0)
	
	DisplayServer.window_set_current_screen(last_screen)
	Debug.logclr("Initial screen: %d" % [last_screen], Debug.SILENT_CLR)
	
	if Platform.is_macos():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		Debug.logclr("Setting fullscreen mode", Debug.SILENT_CLR)
	
	if Platform.is_linux():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_MAILBOX)
		Debug.logclr("Setting vsync to mailbox", Debug.SILENT_CLR)


func _exit_tree() -> void:
		var last_screen = DisplayServer.window_get_current_screen()
		DataSaver.set_value("settings", "last_screen", last_screen)

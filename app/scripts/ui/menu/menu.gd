extends Control

@export var ui_events: UiEvents

var window: Window
var initial_screen_set: bool
var last_screen_size: Vector2i
var last_dpi: int


func _enter_tree() -> void:
	change_window_settings()


func _ready() -> void:
	window = get_window()
	
	window.focus_entered.connect(set_initial_screen)
	window.dpi_changed.connect(scale_content)
	resized.connect(on_resized)
	
	on_resized()
	scale_content()


func on_resized() -> void:
	var screen_size = DisplayServer.screen_get_size()
	if screen_size != last_screen_size:
		last_screen_size = screen_size
		Debug.logclr("Screen size: %dx%d" % [screen_size.x, screen_size.y], Debug.SILENT_CLR)
	
	Debug.logclr("Ui resized: %dx%d" % [size.x, size.y], Debug.SILENT_CLR)
	ui_events.ui_size_changed_emit(size)
	scale_content()


func change_window_settings() -> void:
	if Platform.is_macos():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		Debug.logclr("Setting fullscreen mode", Debug.SILENT_CLR)
	
	if Platform.is_linux():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_MAILBOX)
		Debug.logclr("Setting vsync to mailbox", Debug.SILENT_CLR)


func scale_content() -> void:
	var screen_scale = DisplayServer.screen_get_scale()
	var screen_dpi = DisplayServer.screen_get_dpi()
	
	if screen_dpi == last_dpi: return
	last_dpi = screen_dpi
	
	if not Platform.is_macos():
		var scale_raw = screen_dpi / 96.0
		screen_scale = get_supported_screen_scale(scale_raw)
		Debug.logclr("DPI: %d / 96 = %.2f" % [screen_dpi, scale_raw], Debug.SILENT_CLR)
	
	get_window().content_scale_factor = screen_scale
	Debug.logclr("Content scale factor: %.2f" % [screen_scale], Debug.SILENT_CLR)


func get_supported_screen_scale(scale_value: float) -> float:
	var allowed_scales = [0.5, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0]
	var closest_scale = allowed_scales[0]
	var smallest_delta = abs(scale_value - closest_scale)
	for allowed_scale in allowed_scales:
		var delta = abs(scale_value - allowed_scale)
		if delta < smallest_delta:
			smallest_delta = delta
			closest_scale = allowed_scale
	return closest_scale


func set_initial_screen() -> void:
	if initial_screen_set: return
	initial_screen_set = true
	
	var last_screen = DataSaver.get_value("settings", "last_screen", 0)
	
	DisplayServer.window_set_current_screen(last_screen)
	Debug.logclr("Initial screen: %d" % [last_screen], Debug.SILENT_CLR)


func _exit_tree() -> void:
	var last_screen = DisplayServer.window_get_current_screen()
	DataSaver.set_value("settings", "last_screen", last_screen)

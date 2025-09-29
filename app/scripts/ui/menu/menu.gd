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
	var screen_scale = get_auto_display_scale()
	if get_window().content_scale_factor == screen_scale: return
	get_window().content_scale_factor = screen_scale
	Debug.logclr("Content scale factor: %.2f" % [screen_scale], Debug.SILENT_CLR)


## From editor scale detection
## https://github.com/godotengine/godot/blob/5675c76461e197d3929a1142cfb84ab1a76ac9dd/editor/editor_settings.cpp#L1575
func get_auto_display_scale() -> float:
	if Platform.is_linux():
		var display_name = DisplayServer.get_name()
		if display_name == "Wayland":
			var main_window_scale = DisplayServer.screen_get_scale(DisplayServer.SCREEN_OF_MAIN_WINDOW)
			var fractional_part = main_window_scale - floor(main_window_scale)
			if DisplayServer.get_screen_count() == 1 or not is_equal_approx(fractional_part, 0.0):
				return main_window_scale
			return DisplayServer.screen_get_max_scale()
	
	if Platform.is_macos() or Platform.get_platform() == Platform.ANDROID:
		return DisplayServer.screen_get_max_scale()
	
	var screen = DisplayServer.window_get_current_screen()
	var screen_size = DisplayServer.screen_get_size(screen)
	if screen_size == Vector2i.ZERO:
		return 1.0
	
	var smallest_dimension = min(screen_size.x, screen_size.y)
	var screen_dpi = DisplayServer.screen_get_dpi(screen)
	if screen_dpi >= 192 and smallest_dimension >= 1400:
		return 2.0
	elif smallest_dimension >= 1700:
		return 1.5
	elif smallest_dimension <= 800:
		return 0.75
	return 1.0


func set_initial_screen() -> void:
	if initial_screen_set: return
	initial_screen_set = true
	
	var last_screen = DataSaver.get_value("settings", "last_screen", 0)
	
	DisplayServer.window_set_current_screen(last_screen)
	Debug.logclr("Initial screen: %d" % [last_screen], Debug.SILENT_CLR)


func _exit_tree() -> void:
	var last_screen = DisplayServer.window_get_current_screen()
	DataSaver.set_value("settings", "last_screen", last_screen)

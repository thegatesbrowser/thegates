extends Control

@export var restore_drag_y_threshold: int = 24
@export var snap_top_threshold_px: int = 8
@export var restored_window_ratio: float = 0.75

var mouse_pressed: bool
var dragging: bool
var was_maximized_at_press: bool
var restored_from_maximize: bool
var pending_maximize_on_release: bool

var press_mouse_global: Vector2i
var press_window_pos: Vector2i
var press_window_size: Vector2i
var drag_offset: Vector2i


func restore_from_maximized(mouse_global: Vector2i) -> void:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var target_size: Vector2i = Vector2i(int(usable.size.x * restored_window_ratio), int(usable.size.y * restored_window_ratio))
	
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await get_tree().process_frame # Wait for window to be resized
	await get_tree().process_frame
	DisplayServer.window_set_size(target_size)
	
	var ratio_x: float = 0.5
	if press_window_size.x > 0:
		ratio_x = clamp(float(press_mouse_global.x - press_window_pos.x) / float(press_window_size.x), 0.0, 1.0)
	var target_pos_x: int = mouse_global.x - int(ratio_x * float(target_size.x))
	var dy: int = press_mouse_global.y - press_window_pos.y
	var titlebar_click_y: int = dy if dy < 32 else 32
	var target_pos_y: int = mouse_global.y - titlebar_click_y
	var new_pos: Vector2i = Vector2i(target_pos_x, target_pos_y)
	DisplayServer.window_set_position(new_pos)
	drag_offset = mouse_global - new_pos


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_pressed = true
			dragging = false
			restored_from_maximize = false
			pending_maximize_on_release = false
			press_mouse_global = DisplayServer.mouse_get_position()
			press_window_pos = DisplayServer.window_get_position()
			press_window_size = DisplayServer.window_get_size()
			was_maximized_at_press = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED
			drag_offset = press_mouse_global - press_window_pos
		else:
			mouse_pressed = false
			if pending_maximize_on_release:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
			pending_maximize_on_release = false
			dragging = false
	if event is InputEventMouseMotion and mouse_pressed:
		var mouse_global: Vector2i = DisplayServer.mouse_get_position()
		if was_maximized_at_press and not restored_from_maximize:
			if abs(mouse_global.y - press_mouse_global.y) >= restore_drag_y_threshold:
				restore_from_maximized(mouse_global)
				restored_from_maximize = true
				dragging = true
		else:
			dragging = true
		if dragging:
			var new_pos: Vector2i = mouse_global - drag_offset
			DisplayServer.window_set_position(new_pos)
			var usable: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			pending_maximize_on_release = mouse_global.y <= usable.position.y + snap_top_threshold_px

# TODO: cleanup ai generated code

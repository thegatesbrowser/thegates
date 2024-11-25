extends ScrollContainer

@export var search: Search
@export var scroll_speed: float


func _input(event: InputEvent) -> void:
	if not search.has_focus(): return
	if event is not InputEventMouseButton: return
	if not get_global_rect().has_point(event.position): return
	if not search.prompt_panel.get_global_rect().has_point(event.position): return
	
	if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP:
		scroll_vertical -= scroll_speed * event.factor
	
	if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
		scroll_vertical += scroll_speed * event.factor

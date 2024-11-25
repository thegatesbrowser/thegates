extends Control

@export var search: Search

var update_position: bool


func _ready() -> void:
	search.resized.connect(change_size)
	search.focus_entered.connect(change_size)


func change_size() -> void:
	global_position = get_parent().global_position
	size.x = search.size.x


func _input(event: InputEvent) -> void:
	if not search.has_focus(): return
	
	if (event is InputEventMouseButton
			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		update_position = true


func _process(_delta: float) -> void:
	if not update_position: return
	
	global_position = get_parent().global_position
	update_position = false

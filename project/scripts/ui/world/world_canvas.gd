extends Control

@export var interpolate: float:
	set(value):
		interpolate = value
		animate(value)

var initial: int
var full_screen: int


func _ready() -> void:
	var viewport_width = ProjectSettings.get_setting("display/window/size/viewport_width", 1152)
	var scale_width = float(custom_minimum_size.x) / viewport_width
	
	full_screen = int(get_parent_control().size.x)
	initial = int(full_screen * scale_width)
	custom_minimum_size.x = initial
	Debug.logclr("WorldCanvas initial: %d full_screen: %d" % [initial, full_screen], Color.DIM_GRAY)


func animate(value: float) -> void:
	custom_minimum_size.x = lerp(initial, full_screen, value)

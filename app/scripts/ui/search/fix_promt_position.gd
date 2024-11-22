extends Control

@export var search_le: LineEdit


func _ready() -> void:
	search_le.resized.connect(change_size)
	search_le.focus_entered.connect(change_size)


func change_size() -> void:
	global_position = get_parent().global_position
	size.x = search_le.size.x

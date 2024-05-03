extends Control


func _ready() -> void:
	await get_tree().process_frame
	global_position = get_parent().global_position

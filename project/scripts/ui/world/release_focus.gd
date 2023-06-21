extends Control


func _input(event: InputEvent) -> void:
	if (has_focus()
			and event is InputEventMouseButton
			and not get_global_rect().has_point(event.position)):
		release_focus()

extends Control


func _show(duration: float) -> void:
	var tween = get_tree().create_tween()
	var shown_pos = Vector2(0, position.y - size.y)
	tween.tween_property(self, "position", shown_pos, duration)


func _hide(duration: float) -> void:
	var tween = get_tree().create_tween()
	var hidden_pos = Vector2(0, position.y + size.y)
	tween.tween_property(self, "position", hidden_pos, duration)

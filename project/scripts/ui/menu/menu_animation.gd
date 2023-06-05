extends AnimationPlayer


func _ready() -> void:
	play("RESET")


func _on_slide_up_pressed() -> void:
	play("show_favorites")


func _on_slide_down_pressed() -> void:
	play("hide_favorites")

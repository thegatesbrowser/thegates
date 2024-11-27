extends TextureRect


func _ready() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(self, "rotation", 360, 50).from(0)

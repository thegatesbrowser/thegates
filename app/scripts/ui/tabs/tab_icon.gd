extends Panel

@export var icon: TextureRect
@export var icon_hires: TextureRect


func _ready() -> void:
	if DisplayServer.screen_get_scale() == 2.0:
		icon.hide()
		icon_hires.show()
	else:
		icon.show()
		icon_hires.hide()

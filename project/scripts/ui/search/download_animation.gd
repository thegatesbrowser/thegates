extends TextureRect

@export var duration: float
@export var start_scale: float
@export var end_scale: float

@onready var start := Vector2(start_scale, start_scale)
@onready var end := Vector2(end_scale, end_scale)
@onready var default = scale


func _ready() -> void:
	animate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENABLED:
		animate()


func animate() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(self, "scale", end, duration).from(start)
	tween.tween_property(self, "scale", start, duration).from(end)

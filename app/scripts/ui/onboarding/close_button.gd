extends Button

@export var content: Control
@export var tween_duration: float
@export var base_modulate: Color
@export var hover_scale: float

var tween: Tween


func _ready() -> void:
	mouse_entered.connect(on_mouse_entered)
	mouse_exited.connect(on_mouse_exited)
	on_mouse_exited()


func on_mouse_entered() -> void:
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.set_parallel(true)
	
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(content, "scale", Vector2.ONE * hover_scale, tween_duration)
	tween.tween_property(content, "modulate", Color.WHITE, tween_duration)


func on_mouse_exited() -> void:
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.set_parallel(true)
	
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(content, "scale", Vector2.ONE, tween_duration)
	tween.tween_property(content, "modulate", base_modulate, tween_duration)

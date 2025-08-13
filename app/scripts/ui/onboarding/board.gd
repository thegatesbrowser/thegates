extends Control
class_name OnboardingBoard

signal request_focus

@export var focus_button: Button
@export var unfocus_color: Color
@export var unfocus_scale: Vector2

var tween: Tween


func _ready() -> void:
	focus_button.pressed.connect(func(): request_focus.emit())
	focus_button.visible = false


func focus(tween_duration: float) -> void:
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(self, "scale", Vector2.ONE, tween_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, tween_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	focus_button.visible = false


func unfocus(tween_duration: float) -> void:
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.set_parallel(true)
	
	tween.tween_property(self, "scale", unfocus_scale, tween_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate", unfocus_color, tween_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	focus_button.visible = true

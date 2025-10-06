extends Control
class_name NotificationPopup

@export var icon: TextureRect
@export var message: Label
@export var root: Control
@export var appear_duration: float = 0.4
@export var hide_duration: float = 0.3
@export var start_offset: Vector2 = Vector2(400.0, 0.0)

var tween: Tween


func _ready() -> void:
	show_notification()


func fill(_message: String, _icon: Texture2D) -> void:
	icon.texture = _icon
	message.text = _message


func show_notification() -> void:
	var target_position: Vector2 = root.position
	root.position = target_position + start_offset
	root.modulate = Color(1.0, 1.0, 1.0, 0.0)
	
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.set_parallel(true)
	
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "position", target_position, appear_duration)
	tween.tween_property(root, "modulate:a", 1.0, appear_duration)


func hide_notification() -> void:
	var target_position: Vector2 = root.position + start_offset
	
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.set_parallel(true)
	
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(root, "position", target_position, hide_duration)
	tween.tween_property(root, "modulate:a", 0.0, hide_duration)
	
	await tween.finished

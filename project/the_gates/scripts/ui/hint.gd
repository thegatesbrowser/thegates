extends Control

@export var section: String = "hints"
@export var key: String = ""
@export var button: BaseButton


func _ready() -> void:
	visible = false
	if key.is_empty() or button == null: Debug.logerr("hint has empty vars")
	var first = DataSaver.get_value(section, key)
	if first == null or not first: show_hint()


func _notification(what: int) -> void:
	if not what == NOTIFICATION_VISIBILITY_CHANGED: return
	if is_visible_in_tree(): play_anim()


func show_hint() -> void:
	visible = true
	play_anim()
	if button != null: button.pressed.connect(hide_hint)


func play_anim() -> void:
	$AnimationPlayer.play("Bounce")


func hide_hint() -> void:
	visible = false
	DataSaver.set_value(section, key, true)

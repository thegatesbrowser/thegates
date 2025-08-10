extends Control

const INITIAL_DELAY = 1.0
const SHOWN = Color(1, 1, 1, 1)
const HIDDEN = Color(1, 1, 1, 0)

@export var root: Control
@export var skip: Button
@export var fade_in: float = 0.2
@export var fade_out: float = 0.2

var tween: Tween


func _ready() -> void:
	skip.pressed.connect(hide_onboarding)
	
	visible = true
	root.visible = false
	root.modulate = HIDDEN
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	
	await get_tree().create_timer(INITIAL_DELAY).timeout
	show_onboarding()


func show_onboarding() -> void:
	if root.visible: return
	
	root.visible = true
	
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.tween_property(root, "modulate", SHOWN, fade_in)
	await tween.finished
	
	root.mouse_filter = Control.MOUSE_FILTER_STOP


func hide_onboarding() -> void:
	if not root.visible: return
	
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.tween_property(root, "modulate", HIDDEN, fade_out)
	await tween.finished
	
	root.visible = false

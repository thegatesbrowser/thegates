extends Control

const SECTION: String = "onboarding"
const KEY: String = "shown"

const INITIAL_DELAY = 1.0
const SHOWN = Color(1, 1, 1, 1)
const HIDDEN = Color(1, 1, 1, 0)

@export var root: Control
@export var close: Button
@export var fade_in: float = 0.2
@export var fade_out: float = 0.2

@export_group("Debug")
@export var show_always: bool

var tween: Tween


func _ready() -> void:
	close.pressed.connect(hide_onboarding)
	
	visible = true
	root.visible = false
	root.modulate = HIDDEN
	
	try_show_onboarding()


func try_show_onboarding() -> void:
	var is_shown = DataSaver.get_value(SECTION, KEY, false)
	if is_shown and not show_always: return
	
	await get_tree().create_timer(INITIAL_DELAY).timeout
	show_onboarding()


func show_onboarding() -> void:
	if root.visible: return
	
	root.visible = true
	
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.tween_property(root, "modulate", SHOWN, fade_in)


func hide_onboarding() -> void:
	if not root.visible: return
	
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.tween_property(root, "modulate", HIDDEN, fade_out)
	
	await tween.finished
	root.visible = false
	
	DataSaver.set_value(SECTION, KEY, true)
	DataSaver.save_data()

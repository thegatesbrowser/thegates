extends Control

const SHOWN = Color(1, 1, 1, 1)
const HIDDEN = Color(1, 1, 1, 0)

@export var gate_events: GateEvents
@export var root: TextureButton
@export var fade_in: float = 1.0
@export var fade_out: float = 0.2

var tween: Tween


func _ready() -> void:
	gate_events.not_responding.connect(show_message)
	root.pressed.connect(hide_message)
	
	visible = true
	root.hide()
	root.modulate = HIDDEN
	root.mouse_filter = Control.MOUSE_FILTER_PASS


func show_message() -> void:
	if root.visible: return
	
	root.show()
	
	if is_instance_valid(tween): tween.stop()
	tween = get_tree().create_tween()
	tween.tween_property(root, "modulate", SHOWN, fade_in)
	await tween.finished
	
	root.mouse_filter = Control.MOUSE_FILTER_STOP


func hide_message() -> void:
	if not root.visible: return
	
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	
	if is_instance_valid(tween): tween.stop()
	tween = get_tree().create_tween()
	tween.tween_property(root, "modulate", HIDDEN, fade_out)
	await tween.finished
	
	root.hide()

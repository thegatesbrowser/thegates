extends Control

@export var gate_events: GateEvents
@export var history: History
@export var root: TextureButton
@export var reload: Button
@export var back: Button
@export var fade_in: float = 1.0
@export var fade_out: float = 0.2

const SHOWN = Color(1, 1, 1, 1)
const HIDDEN = Color(1, 1, 1, 0)

var tween: Tween


func _ready() -> void:
	gate_events.not_responding.connect(show_message)
	reload.pressed.connect(reload_gate)
	root.pressed.connect(hide_message)
	back.pressed.connect(Navigation.go_back)
	
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


func reload_gate() -> void:
	var location = history.get_current()
	if Url.is_valid(location):
		gate_events.open_gate_emit(location)

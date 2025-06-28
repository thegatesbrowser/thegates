extends Control
class_name BookmarkUI

@export var gate_events: GateEvents
@export var icon: TextureRect
@export var title: Label
@export var button: Button
@export var button_special: Button

var url: String


func _ready() -> void:
	button.pressed.connect(on_pressed)
	button_special.pressed.connect(on_pressed)


func fill(gate: Gate, special: bool = false) -> void:
	if gate == null: return
	
	button.visible = not special
	button_special.visible = special
	
	url = gate.url
	title.text = "Unnamed" if gate.title.is_empty() else gate.title
	icon.texture = FileTools.load_external_tex(gate.icon)


func on_pressed() -> void:
	if url.is_empty(): return
	gate_events.open_gate_emit(url)

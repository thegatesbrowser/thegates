extends Control
class_name BookmarkUI

@export var gate_events: GateEvents
@export var image: TextureRect
@export var title: Label
@export var button: Button

var url: String


func _ready() -> void:
	button.pressed.connect(on_pressed)


func fill(gate: Gate) -> void:
	if gate == null: return
	
	url = gate.url
	title.text = "Unnamed" if gate.title.is_empty() else gate.title
	image.texture = FileTools.load_external_tex(gate.image)


func on_pressed() -> void:
	if url.is_empty(): return
	gate_events.open_gate_emit(url)

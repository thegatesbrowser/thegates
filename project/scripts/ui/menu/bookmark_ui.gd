extends Node
class_name BookmarkUI

@export var gate_events: GateEvents
@export var image: TextureRect
@export var title: Label

var url: String


func fill(gate: Gate) -> void:
	if gate == null: return
	
	url = gate.url
	title.text = "Unnamed" if gate.title.is_empty() else gate.title
	image.texture = FileTools.load_external_tex(gate.image)


func _on_base_button_pressed() -> void:
	if url.is_empty(): return
	gate_events.open_gate_emit(url)

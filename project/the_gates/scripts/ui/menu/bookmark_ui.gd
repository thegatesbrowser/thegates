extends Node
class_name BookmarkUI

@export var gate_events: GateEvents
@export var image: TextureRect
@export var title: Label

var gate: Gate


func fill(_gate: Gate) -> void:
	if _gate == null: return
	gate = _gate
	
	title.text = "Unnamed" if gate.title.is_empty() else gate.title
	image.texture = FileTools.load_external_tex(gate.image)


func _on_base_button_pressed() -> void:
	if gate == null or gate.url.is_empty(): return
	gate_events.open_gate_emit(gate.url)

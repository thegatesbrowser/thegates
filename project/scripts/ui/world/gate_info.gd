extends Control

@export var gate_events: GateEvents

@export var image: TextureRect
@export var title: Label
@export var description: RichTextLabel

var gate: Gate


func _ready() -> void:
	gate_events.gate_info_loaded.connect(display_info)


func display_info(_gate: Gate) -> void:
	gate = _gate
	title.text = "Unnamed" if gate.title.is_empty() else gate.title
	description.text = "No description" if gate.description.is_empty() else gate.description
	image.texture = FileTools.load_external_tex(gate.image)

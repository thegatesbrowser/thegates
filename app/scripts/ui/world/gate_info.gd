extends Control

@export var gate_events: GateEvents

@export var image: TextureRect
@export var image_darken: Control
@export var title: RichTextLabel
@export var description: RichTextLabel
@export var gate_status: Array[Control]

var gate: Gate


func _ready() -> void:
	gate_events.gate_info_loaded.connect(display_info)
	gate_events.first_frame.connect(on_first_frame)
	gate_events.gate_error.connect(on_gate_error)
	clear_info()


func display_info(_gate: Gate, _is_cached: bool) -> void:
	gate = _gate
	title.text = "Unnamed" if gate.title.is_empty() else gate.title
	description.text = "No description" if gate.description.is_empty() else gate.description
	image.texture = FileTools.load_external_tex(gate.image)
	if is_instance_valid(image.texture): image_darken.show()


func clear_info() -> void:
	gate = null
	title.text = ""
	description.text = ""
	image.texture = null
	image_darken.hide()


func on_first_frame() -> void:
	for node in gate_status:
		node.hide()


func on_gate_error(_code: GateEvents.GateError) -> void:
	description.set_text("")

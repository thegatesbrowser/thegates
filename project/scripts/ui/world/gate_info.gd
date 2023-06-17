extends Control

@export var gate_events: GateEvents
@export var bookmarks: Bookmarks

@export var image: TextureRect
@export var title: Label
@export var description: RichTextLabel
@export var url: LineEdit

@export var star: Control
@export var unstar: Control

var gate: Gate


func _ready() -> void:
	star.visible = false
	unstar.visible = false
	gate_events.gate_info_loaded.connect(display_info)


func display_info(_gate: Gate) -> void:
	gate = _gate
	title.text = "Unnamed" if gate.title.is_empty() else gate.title
	description.text = "No description" if gate.description.is_empty() else gate.description
	url.text = gate.url.replace("world.gate", "")
	image.texture = FileTools.load_external_tex(gate.image)
	
	if bookmarks.is_featured(gate.url):
		bookmarks.update(gate)
		star.visible = false
		unstar.visible = false
	elif bookmarks.gates.has(gate.url):
		bookmarks.update(gate)
		star.visible = false
		unstar.visible = true
	else:
		star.visible = true
		unstar.visible = false


func _on_star_pressed() -> void:
	bookmarks.star(gate)
	star.visible = false
	unstar.visible = true


func _on_unstar_pressed() -> void:
	bookmarks.unstar(gate)
	star.visible = true
	unstar.visible = false

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


func fill(gate: Gate) -> void:
	if gate == null: return
	
	button.visible = not gate.is_special
	button_special.visible = gate.is_special
	
	url = gate.url
	title.text = "Unnamed" if gate.title.is_empty() else gate.title
	
	var icon_path = gate.icon
	if icon_path.is_empty(): icon_path = await FileDownloader.download(gate.icon_url)
	
	icon.texture = FileTools.load_external_tex(icon_path)


func on_pressed() -> void:
	if url.is_empty(): return
	gate_events.open_gate_emit(url)

extends Control
class_name BookmarkUI

@export var gate_events: GateEvents
@export var ui_events: UiEvents
@export var icon: TextureRect
@export var title: Label
@export var button: Button
@export var special_effect: Panel

var url: String
var is_special: bool


func _ready() -> void:
	button.pressed.connect(on_pressed)
	ui_events.onboarding_started.connect(update_button_type)
	ui_events.onboarding_finished.connect(update_button_type)


func fill(gate: Gate) -> void:
	if gate == null: return
	
	url = gate.url
	is_special = gate.is_special
	title.text = "Unnamed" if gate.title.is_empty() else gate.title
	update_button_type()
	
	var icon_path = gate.icon
	if icon_path.is_empty(): icon_path = await FileDownloader.download(gate.icon_url)
	
	icon.texture = FileTools.load_external_tex(icon_path)
	


func update_button_type() -> void:
	if ui_events.is_onboarding_started:
		special_effect.visible = false
	else:
		special_effect.visible = is_special


func on_pressed() -> void:
	if url.is_empty(): return
	gate_events.open_gate_emit(url)

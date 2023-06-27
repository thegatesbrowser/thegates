extends Control
class_name SearchResult

@export var gate_events: GateEvents

@export var url: Label
@export var title: Label
@export var description: RichTextLabel
@export var image: TextureRect


func fill(gate: Dictionary) -> void:
	if gate == null: return
	
	url.text = gate["url"]
	title.text = "Unnamed" if gate["title"].is_empty() else gate["title"]
	description.text = gate["description"]
	
	var image_path = await FileDownloader.download(gate["image"])
	image.texture = FileTools.load_external_tex(image_path)


func _on_button_pressed() -> void:
	if url.text.is_empty(): return
	gate_events.open_gate_emit(url.text)

extends Control
class_name SearchResult

const KEY_URL = "url"
const KEY_TITLE = "title"
const KEY_DESCRIPTION = "description"
const KEY_ICON = "icon"
const KEY_IMAGE = "image"

@export var gate_events: GateEvents

@export var url: Label
@export var title: Label
@export var description: RichTextLabel
@export var icon: TextureRect


func fill(gate: Dictionary) -> void:
	if gate == null: return
	
	url.text = gate[KEY_URL]
	title.text = "Unnamed" if gate[KEY_TITLE].is_empty() else gate[KEY_TITLE]
	description.text = gate[KEY_DESCRIPTION]
	
	var icon_url = gate[KEY_ICON] if not gate[KEY_ICON].is_empty() else gate[KEY_IMAGE]
	var icon_path = await FileDownloader.download(icon_url)
	icon.texture = FileTools.load_external_tex(icon_path)


func _on_button_pressed() -> void:
	if url.text.is_empty(): return
	gate_events.open_gate_emit(url.text)

extends BaseButton

@export var gate_events: GateEvents


func _ready() -> void:
	visible = false


func _on_search_text_changed(_url: String) -> void:
	visible = true if Url.is_valid(_url) else false

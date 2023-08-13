extends BaseButton

@export var gate_events: GateEvents


func _ready() -> void:
	visible = false


func _on_search_text_changed(_url: String) -> void:
	#visible = true if not _url.is_empty() else false
	pass

extends Button
class_name Suggestion

@export var gate_events: GateEvents
@export var prompt: String


func fill(_prompt: String) -> void:
	prompt = _prompt
	text = _prompt


func _on_button_pressed() -> void:
	if prompt.is_empty(): return

	gate_events.search_emit(prompt)

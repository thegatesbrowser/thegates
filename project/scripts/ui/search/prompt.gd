extends Control
class_name PromptResult

@export var gate_events: GateEvents
@export var prompt_text: Label


func fill(prompt: Dictionary) -> void:
	if prompt == null: return
	
	var text: String = prompt["prompt"].to_lower()
	text = StringTools.to_alpha(text)
	prompt_text.text = text


func _on_button_pressed() -> void:
	if prompt_text.text.is_empty(): return
	gate_events.search_emit(prompt_text.text)

extends Button
class_name PromptResult

@export var gate_events: GateEvents
@export var prompt_text: Label
@export var focus_style: StyleBox

var normal_style: StyleBox


func _ready() -> void:
	normal_style = get_theme_stylebox("normal", "")


func fill(prompt: String) -> void:
	if prompt.is_empty(): return
	prompt_text.text = prompt.to_lower()


func _on_button_pressed() -> void:
	if prompt_text.text.is_empty(): return
	gate_events.search_emit(prompt_text.text)


func focus() -> void:
	add_theme_stylebox_override("normal", focus_style)


func unfocus() -> void:
	add_theme_stylebox_override("normal", normal_style)

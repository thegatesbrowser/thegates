extends LineEdit
class_name Search

signal on_release_focus
signal on_navigation(event: int)

@export var gate_events: GateEvents
@export var prompt_panel: Control


func _ready() -> void:
	gate_events.open_gate.connect(set_current_url)
	gate_events.search.connect(set_current_url)
	gate_events.exit_gate.connect(set_current_url.bind(""))


func set_current_url(_url: String) -> void:
	text = _url
	
	on_release_focus.emit()


func _on_text_submitted(_url: String) -> void:
	open_gate()


func _on_go_pressed() -> void:
	open_gate()


func open_gate() -> void:
	if text.is_empty(): return
	
	if Url.is_valid(text):
		gate_events.open_gate_emit(text)
	else:
		gate_events.search_emit(text)
	
	release_focus()
	on_release_focus.emit()


func _input(event: InputEvent) -> void:
	if not has_focus(): return
	
	if (event is InputEventMouseButton
			and not get_global_rect().has_point(event.position)
			and not prompt_panel.get_global_rect().has_point(event.position)):
		release_focus()
		on_release_focus.emit()
	
	if event.is_action_pressed("ui_text_caret_up"):
		on_navigation.emit(PromptNavigation.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_text_caret_down"):
		on_navigation.emit(PromptNavigation.DOWN)
		get_viewport().set_input_as_handled()

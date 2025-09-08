extends LineEdit
class_name Search

signal on_release_focus
signal on_navigation(event: int)

@export var ui_events: UiEvents
@export var gate_events: GateEvents
@export var prompt_panel: Control
@export var focus_on_ready: bool


func _ready() -> void:
	gate_events.open_gate.connect(set_current_url)
	gate_events.search.connect(set_current_url)
	gate_events.exit_gate.connect(set_current_url.bind(""))
	
	if focus_on_ready: grab_focus()


func set_current_url(_url: String) -> void:
	text = _url
	
	stop_typing()


func _on_text_submitted(_url: String) -> void: # url might be empty
	open_gate()


func open_gate() -> void:
	if text.is_empty(): return
	
	if Url.is_valid(text):
		gate_events.open_gate_emit(text)
	else:
		gate_events.search_emit(text)
	
	stop_typing()


func _input(event: InputEvent) -> void:
	if not has_focus(): return
	if not ui_events.is_typing_search: ui_events.set_typing_search(true)
	
	if (event is InputEventMouseButton
			and not get_global_rect().has_point(event.position)
			and not prompt_panel.get_global_rect().has_point(event.position)
			and not event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		
		stop_typing()
	
	if event.is_action_pressed("ui_text_clear_carets_and_selection"):
		stop_typing()
	
	if event.is_action_pressed("ui_text_caret_up"):
		on_navigation.emit(PromptNavigation.UP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_text_caret_down"):
		on_navigation.emit(PromptNavigation.DOWN)
		get_viewport().set_input_as_handled()


func stop_typing() -> void:
	if ui_events.is_typing_search: ui_events.set_typing_search(false)
	release_focus()
	on_release_focus.emit()

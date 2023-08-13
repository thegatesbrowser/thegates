extends LineEdit
class_name Search

signal on_release_focus

@export var gate_events: GateEvents
@export var prompt_panel: Control

var url: String


func _ready() -> void:
	gate_events.open_gate.connect(set_current_url)
	gate_events.search.connect(set_current_url)
	gate_events.exit_gate.connect(set_current_url.bind(""))


func set_current_url(_url: String) -> void:
	url = _url
	text = url
	
	on_release_focus.emit()


func _input(event: InputEvent) -> void:
	if (has_focus() and event is InputEventMouseButton
			and not get_global_rect().has_point(event.position)
			and not prompt_panel.get_global_rect().has_point(event.position)):
		release_focus()
		on_release_focus.emit()


func _on_text_changed(_url: String) -> void:
	url = _url


func _on_text_submitted(_url: String) -> void:
	open_gate()


func _on_go_pressed() -> void:
	open_gate()


func open_gate() -> void:
	if url.is_empty(): return
	
	if Url.is_valid(url):
		gate_events.open_gate_emit(url)
	else:
		gate_events.search_emit(url)
	
	release_focus()
	on_release_focus.emit()

extends LineEdit

@export var gate_events: GateEvents
var url: String


func _input(event: InputEvent) -> void:
	if (has_focus()
			and event is InputEventMouseButton
			and not get_global_rect().has_point(event.position)):
		release_focus()


func _on_text_changed(_url: String) -> void:
	url = _url


func _on_text_submitted(_url: String) -> void:
	open_gate()


func _on_go_pressed() -> void:
	open_gate()


func open_gate() -> void:
	gate_events.search_pressed_emit(url)
	if Url.is_valid(url):
		release_focus()
		gate_events.open_gate_emit(url)
	else:
		shake()


func shake() -> void:
	release_focus()
	var tween = get_tree().create_tween()
	var pos = position
	const delta = Vector2(0, 5)
	const duration = 0.07
	tween.tween_property(self, "position", pos + delta, duration)
	tween.tween_property(self, "position", pos - delta, duration)
	tween.tween_property(self, "position", pos + delta, duration)
	tween.tween_property(self, "position", pos - delta, duration)
	tween.tween_property(self, "position", pos, duration)
	await tween.finished
	grab_focus()
	

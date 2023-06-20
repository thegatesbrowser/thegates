extends Node

@export var gate_events: GateEvents
@export var history: History

@export var go_back: BaseButton
@export var go_forw: BaseButton
@export var reload: BaseButton
@export var home: BaseButton


func _ready() -> void:
	gate_events.open_gate.connect(on_open_gate)
	
	go_back.pressed.connect(on_go_back)
	go_forw.pressed.connect(on_go_forw)
	reload.pressed.connect(on_reload)
	home.pressed.connect(on_home)
	
	disable([go_back, go_forw, reload, home])


func on_open_gate(url: String) -> void:
	history.add(url)
	enable([go_back, reload, home])
	if not history.can_forw():
		disable([go_forw])


func on_go_back() -> void:
	var url = history.back()
	
	enable([go_forw])
	if history.can_back():
		gate_events.open_gate_emit(url)
	else:
		disable([go_back, reload, home])
		gate_events.exit_gate_emit()


func on_go_forw() -> void:
	var url = history.forw()
	
	enable([go_back])
	if not history.can_forw():
		disable([go_forw])
	
	gate_events.open_gate_emit(url)


func on_reload() -> void:
	gate_events.open_gate_emit(history.get_current())


func on_home() -> void:
	history.clear()
	disable([go_back, go_forw, reload, home])
	gate_events.exit_gate_emit()


func disable(buttons: Array[BaseButton]) -> void:
	for button in buttons:
		button.disabled = true
		button.modulate.a = 0.5
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW


func enable(buttons: Array[BaseButton]) -> void:
	for button in buttons:
		button.disabled = false
		button.modulate.a = 1
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

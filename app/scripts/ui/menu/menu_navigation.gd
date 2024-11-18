extends Node

@export var gate_events: GateEvents
@export var history: History

@export var go_back: RoundButton
@export var go_forw: RoundButton
@export var reload: RoundButton
@export var home: RoundButton


func _ready() -> void:
	gate_events.open_gate.connect(on_new)
	gate_events.search.connect(on_new)
	
	go_back.pressed.connect(on_go_back)
	go_forw.pressed.connect(on_go_forw)
	reload.pressed.connect(on_reload)
	home.pressed.connect(on_home)
	
	disable([go_back, go_forw, reload, home])


func on_new(location: String) -> void:
	history.add(location)
	enable([go_back, reload, home])
	if not history.can_forw():
		disable([go_forw])


func on_go_back() -> void:
	var location = history.back()
	
	enable([go_forw])
	if history.can_back():
		open(location)
	else:
		disable([go_back, reload, home])
		gate_events.exit_gate_emit()


func on_go_forw() -> void:
	var location = history.forw()
	
	enable([go_back])
	if not history.can_forw():
		disable([go_forw])
	
	open(location)


func on_reload() -> void:
	open(history.get_current())


func on_home() -> void:
	history.clear()
	disable([go_back, go_forw, reload, home])
	gate_events.exit_gate_emit()


func open(location: String) -> void:
	if Url.is_valid(location):
		gate_events.open_gate_emit(location)
	else:
		gate_events.search_emit(location)


func disable(buttons: Array[RoundButton]) -> void:
	for button in buttons:
		button.disable()


func enable(buttons: Array[RoundButton]) -> void:
	for button in buttons:
		button.enable()

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
	gate_events.exit_gate.connect(on_new.bind(""))
	
	go_back.pressed.connect(on_go_back)
	go_forw.pressed.connect(on_go_forw)
	reload.pressed.connect(on_reload)
	home.pressed.connect(gate_events.exit_gate_emit)
	
	go_back.disable()
	go_forw.disable()


func on_new(location: String) -> void:
	history.add(location)
	update_buttons()


func on_go_back() -> void:
	open(history.back())
	update_buttons()


func on_go_forw() -> void:
	open(history.forw())
	update_buttons()


func on_reload() -> void:
	open(history.get_current())


func open(location: String) -> void:
	if location == "":
		gate_events.exit_gate_emit()
	elif Url.is_valid(location):
		gate_events.open_gate_emit(location)
	else:
		gate_events.search_emit(location)


func update_buttons() -> void:
	if history.can_back(): go_back.enable()
	else: go_back.disable()
	
	if history.can_forw(): go_forw.enable()
	else: go_forw.disable()

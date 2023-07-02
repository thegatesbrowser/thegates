extends Control

@export var gate_events: GateEvents
@export var search_line_edit: LineEdit

@export var search: Control
@export var downloading: Control
@export var success: Control
@export var error: Control


func _ready() -> void:
	search_line_edit.text_changed.connect(func(_text): switch_to(search))
	gate_events.exit_gate.connect(func(): switch_to(search))
	gate_events.open_gate.connect(func(_url): switch_to(downloading))
	gate_events.gate_entered.connect(func(): switch_to(success))
	gate_events.gate_error.connect(func(_code): switch_to(error))
	
	switch_to(search)


func switch_to(_state: Control) -> void:
	disable([search, downloading, success, error])
	_state.visible = true
	_state.process_mode = Node.PROCESS_MODE_INHERIT


func disable(states: Array[Control]) -> void:
	for state in states:
		state.visible = false
		state.process_mode = Node.PROCESS_MODE_DISABLED

extends Node
#class_name Navigation

signal updated()

@export var gate_events: GateEvents
@export var history: History


func _ready() -> void:
	gate_events.open_gate.connect(new)
	gate_events.search.connect(new)
	gate_events.exit_gate.connect(new.bind(""))


func can_forw() -> bool:
	return history.can_forw()


func can_back() -> bool:
	return history.can_back()


func new(location: String) -> void:
	history.add(location)
	updated.emit()


func go_back() -> void:
	open(history.back())
	updated.emit()


func go_forw() -> void:
	open(history.forw())
	updated.emit()


func reload() -> void:
	open(history.get_current())
	updated.emit()


func home() -> void:
	gate_events.exit_gate_emit()


func open(location: String) -> void:
	if location == "":
		gate_events.exit_gate_emit()
	elif Url.is_valid(location):
		gate_events.open_gate_emit(location)
	else:
		gate_events.search_emit(location)

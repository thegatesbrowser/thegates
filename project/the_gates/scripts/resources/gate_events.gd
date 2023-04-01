extends Resource
class_name GateEvents

signal open_gate(url: String)
signal gate_info_loaded(gate: Gate)
signal gate_loaded(gate: Gate)
signal gate_entered
signal exit_gate

var current_gate_url: String
var current_gate: Gate


func open_gate_emit(url: String) -> void:
	current_gate_url = Url.fix_gate_url(url)
	open_gate.emit()


func gate_info_loaded_emit(gate: Gate) -> void:
	current_gate = gate
	gate_info_loaded.emit(gate)


func gate_loaded_emit(gate: Gate) -> void:
	current_gate = gate
	gate_loaded.emit(gate)


func gate_entered_emit() -> void:
	gate_entered.emit()


func exit_gate_emit() -> void:
	current_gate_url = ""
	current_gate = null
	exit_gate.emit()

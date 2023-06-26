extends Resource
class_name GateEvents

signal search(query: String)
signal open_gate(url: String)
signal gate_config_loaded(url: String, config: ConfigGate)
signal gate_info_loaded(gate: Gate)
signal gate_loaded(gate: Gate)
signal gate_entered
signal exit_gate

var current_search_query: String
var current_gate_url: String
var current_gate: Gate


func open_gate_emit(url: String) -> void:
	current_gate_url = Url.fix_gate_url(url)
	current_search_query = ""
	
	open_gate.emit(current_gate_url)


func search_emit(query: String) -> void:
	current_search_query = query
	current_gate_url = ""
	
	search.emit(query)


func gate_config_loaded_emit(url: String, config: ConfigGate) -> void:
	gate_config_loaded.emit(url, config)


func gate_info_loaded_emit(gate: Gate) -> void:
	current_gate = gate
	gate_info_loaded.emit(gate)


func gate_loaded_emit(gate: Gate) -> void:
	current_gate = gate
	gate_loaded.emit(gate)


func gate_entered_emit() -> void:
	gate_entered.emit()


func exit_gate_emit() -> void:
	current_search_query = ""
	current_gate_url = ""
	current_gate = null
	
	exit_gate.emit()

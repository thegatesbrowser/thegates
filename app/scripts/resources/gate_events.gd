extends Resource
class_name GateEvents

signal search(query: String)
signal open_gate(url: String)
signal gate_config_loaded(url: String, config: ConfigGate)
signal gate_info_loaded(gate: Gate, is_cached: bool)
signal gate_loaded(gate: Gate)
signal gate_entered
signal exit_gate

signal download_progress(url: String, body_size: int, downloaded_bytes: int)
signal gate_error(code: GateError)

enum GateError
{
	NOT_FOUND,
	MISSING_PACK,
	MISSING_LIBS
}

var current_search_query: String
var current_gate_url: String
var current_gate: Gate


func search_emit(query: String) -> void:
	current_search_query = query
	current_gate_url = ""
	
	search.emit(query)


func open_gate_emit(url: String) -> void:
	current_gate_url = Url.fix_gate_url(url)
	current_search_query = ""
	
	open_gate.emit(current_gate_url)


func gate_config_loaded_emit(url: String, config: ConfigGate) -> void:
	gate_config_loaded.emit(url, config)


func gate_info_loaded_emit(gate: Gate, is_cached: bool) -> void:
	current_gate = gate
	gate_info_loaded.emit(gate, is_cached)


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


func download_progress_emit(url: String, body_size: int, downloaded_bytes: int) -> void:
	download_progress.emit(url, body_size, downloaded_bytes)


func gate_error_emit(code: GateError) -> void:
	gate_error.emit(code)

extends Resource
class_name GateEvents

signal search(query: String)
signal open_gate(url: String)
signal gate_config_loaded(url: String, config: ConfigGate)
signal gate_info_loaded(gate: Gate)
signal gate_icon_loaded(gate: Gate) # might be empty icon
signal gate_image_loaded(gate: Gate) # might be empty image
signal gate_loaded(gate: Gate)
signal gate_entered
signal first_frame
signal not_responding
signal exit_gate

signal download_progress(url: String, body_size: int, downloaded_bytes: int)
signal gate_error(code: GateError)

enum GateError
{
	NOT_FOUND,
	INVALID_CONFIG,
	MISSING_PACK,
	MISSING_LIBS,
	MISSING_RENDERER
}

enum Early
{
	INFO_LOADED,
	ICON_LOADED,
	IMAGE_LOADED,
	ALL_LOADED,
	ENTERED
}

# Track if events have been emitted
var emitted_events: Array[Early] = []

var current_search_query: String
var current_gate_url: String
var current_gate: Gate


func search_emit(query: String) -> void:
	clear_current_gate()
	current_search_query = query
	search.emit(query)


func open_gate_emit(url: String) -> void:
	clear_current_gate()
	current_gate_url = Url.fix_gate_url(url)
	open_gate.emit(current_gate_url)


func gate_config_loaded_emit(url: String, config: ConfigGate) -> void:
	gate_config_loaded.emit(url, config)


func gate_info_loaded_emit(gate: Gate) -> void:
	current_gate = gate
	emitted_events.append(Early.INFO_LOADED)
	gate_info_loaded.emit(gate)


func gate_icon_loaded_emit(gate: Gate) -> void:
	emitted_events.append(Early.ICON_LOADED)
	gate_icon_loaded.emit(gate)


func gate_image_loaded_emit(gate: Gate) -> void:
	emitted_events.append(Early.IMAGE_LOADED)
	gate_image_loaded.emit(gate)


func gate_loaded_emit(gate: Gate) -> void:
	current_gate = gate
	emitted_events.append(Early.ALL_LOADED)
	gate_loaded.emit(gate)


func gate_entered_emit() -> void:
	emitted_events.append(Early.ENTERED)
	gate_entered.emit()


func first_frame_emit() -> void:
	first_frame.emit()


func not_responding_emit() -> void:
	not_responding.emit()


func exit_gate_emit() -> void:
	clear_current_gate()
	exit_gate.emit()


func download_progress_emit(url: String, body_size: int, downloaded_bytes: int) -> void:
	download_progress.emit(url, body_size, downloaded_bytes)


func gate_error_emit(code: GateError) -> void:
	gate_error.emit(code)


func call_or_subscribe(event: Early, callback: Callable) -> void:
	if emitted_events.has(event):
		if event == Early.ENTERED:
			callback.call()
		else:
			callback.call(current_gate)
	else:
		match event:
			Early.INFO_LOADED:
				gate_info_loaded.connect(callback)
			Early.ICON_LOADED:
				gate_icon_loaded.connect(callback)
			Early.IMAGE_LOADED:
				gate_image_loaded.connect(callback)
			Early.ALL_LOADED:
				gate_loaded.connect(callback)
			Early.ENTERED:
				gate_entered.connect(callback)


func clear_current_gate() -> void:
	current_search_query = ""
	current_gate_url = ""
	current_gate = null
	
	emitted_events.clear()

extends Node
class_name SandboxLogger

@export var gate_events: GateEvents

const LOG_FOLDER := "user://logs"
const LOG_FILE := "log.txt"

var log_file: FileAccess
var pipe: Dictionary
var is_started: bool
var logs_sent: bool


func _ready() -> void:
	gate_events.not_responding.connect(send_logs)


func start(_pipe: Dictionary, gate: Gate) -> void:
	pipe = _pipe
	is_started = true
	
	var gate_folder = gate.url.replace("http://", "").replace("https://", "").replace(".gate", "")
	var path = LOG_FOLDER + "/" + gate_folder + "/" + LOG_FILE
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	
	log_file = FileAccess.open(path, FileAccess.WRITE_READ)
	Debug.logclr("Logs written to " + path, Color.DIM_GRAY)


func _process(_delta: float) -> void:
	if not is_started: return
	
	if pipe["stdio"].is_open():
		var buffer = PackedByteArray()
		
		while true:
			buffer.append_array(pipe["stdio"].get_buffer(2048))
			if pipe["stdio"].get_error() != OK:
				break;
		
		while true:
			buffer.append_array(pipe["stderr"].get_buffer(2048))
			if pipe["stderr"].get_error() != OK:
				break;
		
		if !buffer.is_empty():
			printraw(buffer.get_string_from_utf8())
			log_file.store_buffer(buffer)


func send_logs() -> void:
	if logs_sent: return
	logs_sent = true
	
	Debug.logr("logs sent")

extends Node
class_name SandboxLogger

@export var gate_events: GateEvents
@export var api: ApiSettings

const LOG_FOLDER := "user://logs"
const LOG_FILE := "log.txt"
const PRINT_LOGS_ARG := "--sandbox-logs"
const FLUSH_DELAY = 5

var flush_timer: Timer

var log_file: FileAccess
var pipe: Dictionary
var gate: Gate

var print_logs: bool
var is_started: bool
var logs_sent: bool


func _ready() -> void:
	gate_events.not_responding.connect(send_logs)
	print_logs = PRINT_LOGS_ARG in OS.get_cmdline_args()


func start(_pipe: Dictionary, _gate: Gate) -> void:
	pipe = _pipe
	gate = _gate
	is_started = true
	
	var path = LOG_FOLDER + "/" + get_folder_name(gate.url) + "/" + LOG_FILE
	var global_path = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	
	log_file = FileAccess.open(path, FileAccess.WRITE_READ)
	Debug.logclr("Logs written to [url]%s[/url]" % [global_path], Color.GRAY)
	
	start_flush_timer()


func get_folder_name(url: String) -> String:
	var folder = gate.url.replace("http://", "").replace("https://", "").replace(".gate", "")
	folder = folder.replace(":", "_") # remove ':' before port
	return folder


func start_flush_timer() -> void:
	flush_timer = Timer.new()
	add_child(flush_timer)
	flush_timer.timeout.connect(flush_logs)
	flush_timer.start(FLUSH_DELAY)


func flush_logs() -> void:
	if not log_file.is_open(): return
	log_file.flush()


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
			if print_logs: printraw(buffer.get_string_from_utf8())
			log_file.store_buffer(buffer)


func send_logs() -> void:
	if not is_started: return
	if logs_sent: return
	logs_sent = true
	
	flush_logs()
	var data = FileAccess.get_file_as_bytes(log_file.get_path())
	var length = data.size()
	
	await send_logs_request(data, length)


func send_logs_request(data: PackedByteArray, length: int) -> void:
	var url = api.send_logs + gate.url.uri_encode()
	var callback = func(_result, code, _headers, _body):
		if code == 200:
			Debug.logclr("Logs were sent %.2fKB" % [length / 1024.0], Color.DIM_GRAY)
		else: Debug.logclr("Sending logs failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request_raw(url, callback, data, HTTPClient.METHOD_POST)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request send_logs", Color.RED)

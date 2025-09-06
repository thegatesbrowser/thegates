extends Node
class_name SandboxLogger

@export var gate_events: GateEvents
@export var api: ApiSettings

const LOG_FOLDER := "user://logs"
const LOG_FILE := "log.txt"
const PRINT_LOGS_ARG := "--sandbox-logs"
const BUFFER_SIZE = 2048
const FLUSH_DELAY = 5

var flush_timer: Timer

var log_file: FileAccess
var pipe: Dictionary
var gate: Gate

var print_logs: bool
var logs_sent: bool

var thread1: Thread = Thread.new()
var thread2: Thread = Thread.new()


func _ready() -> void:
	gate_events.not_responding.connect(send_logs)
	print_logs = PRINT_LOGS_ARG in OS.get_cmdline_args()


func start(_pipe: Dictionary, _gate: Gate) -> void:
	pipe = _pipe
	gate = _gate
	
	create_log_file()
	start_reading_pipes()
	start_flushing_logs()


func create_log_file() -> void:
	var folder = gate.url.split("?")[0].replace("http://", "").replace("https://", "").replace(".gate", "")
	folder = folder.replace(":", "_") # remove ':' before port
	
	var path = LOG_FOLDER + "/" + folder + "/" + LOG_FILE
	var global_path = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	
	log_file = FileAccess.open(path, FileAccess.WRITE_READ)
	Debug.logclr("Logs written to [url]%s[/url]" % [global_path], Color.GRAY)


# READING FROM PIPES

func start_reading_pipes() -> void:
	thread1 = Thread.new()
	thread2 = Thread.new()
	thread1.start(read_stdio)
	thread2.start(read_stderr)


func read_stdio() -> void:
	var stdio = pipe["stdio"] as FileAccess
	var buffer: PackedByteArray
	
	while stdio.is_open():
		buffer = stdio.get_buffer(BUFFER_SIZE)
		if not buffer.is_empty():
			store_buffer.call_deferred(buffer)
		else:
			OS.delay_msec(10)


func read_stderr() -> void:
	var stderr = pipe["stderr"] as FileAccess
	var buffer: PackedByteArray
	
	while stderr.is_open():
		buffer = stderr.get_buffer(BUFFER_SIZE)
		if not buffer.is_empty():
			store_buffer.call_deferred(buffer)
		else:
			OS.delay_msec(10)


func store_buffer(buffer: PackedByteArray) -> void:
	if print_logs: printraw(buffer.get_string_from_utf8())
	log_file.store_buffer(buffer)


func cleanup() -> void:
	if pipe.has("stdio"): pipe["stdio"].close()
	if pipe.has("stderr"): pipe["stderr"].close()
	if thread1 != null and thread1.is_started(): thread1.wait_to_finish()
	if thread2 != null and thread2.is_started(): thread2.wait_to_finish()


# FLUSH AND SEND LOGS

func start_flushing_logs() -> void:
	flush_timer = Timer.new()
	add_child(flush_timer)
	flush_timer.timeout.connect(flush_logs)
	flush_timer.start(FLUSH_DELAY)


func flush_logs() -> void:
	if log_file == null or not log_file.is_open(): return
	log_file.flush()


func send_logs() -> void:
	if log_file == null or logs_sent: return
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
	if err != OK: Debug.logclr("Cannot send request send_logs", Color.RED)

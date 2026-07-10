extends Node
class_name RendererLogger

@export var gate_events: GateEvents
@export var api: ApiSettings
@export var renderer_manager: RendererManager

const LOG_FOLDER := "user://logs"
const LOG_FILE := "log.txt"
const PRINT_LOGS_ARG := "--renderer-logs"
const BUFFER_SIZE = 2048
const FLUSH_DELAY = 5
const MAX_UPLOAD_BYTES = 1048576

var flush_timer: Timer

var log_path: String
var log_file: FileAccess
var pipe: Dictionary
var gate: Gate

var print_logs: bool
var logs_sent: bool
var first_frame_reached: bool
var start_ms: int
var log_size: int

var thread1: Thread
var thread2: Thread


func _ready() -> void:
	gate_events.not_responding.connect(send_logs)
	gate_events.first_frame.connect(func(): first_frame_reached = true)
	print_logs = PRINT_LOGS_ARG in OS.get_cmdline_args()


func start(_pipe: Dictionary, _gate: Gate) -> void:
	pipe = _pipe
	gate = _gate
	start_ms = Time.get_ticks_msec()

	log_path = log_file_path(gate.url)
	DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())
	Debug.logclr("Logs written to [url]%s[/url]" % [ProjectSettings.globalize_path(log_path)], Color.GRAY)

	# sandboxed children write the log themselves; opening it here would truncate it
	if pipe.has("stdio") and pipe.has("stderr"):
		create_log_file()
		start_reading_pipes()
	start_flushing_logs()


func create_log_file() -> void:
	log_file = FileAccess.open(log_path, FileAccess.WRITE_READ)


static func log_file_path(url: String) -> String:
	return LOG_FOLDER.path_join(RendererManager.gate_folder(url)).path_join(LOG_FILE)


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


func send_logs(reason: String = "not_responding") -> void:
	if log_path.is_empty() or logs_sent: return
	logs_sent = true

	flush_logs()
	var data := read_log_tail()

	var body := build_log_header(reason).to_utf8_buffer()
	body.append_array(data)
	await send_logs_request(body, body.size())


# error-spam logs can be huge; the server rejects bodies over a few MB
func read_log_tail() -> PackedByteArray:
	var file := FileAccess.open(log_path, FileAccess.READ)
	if file == null: return PackedByteArray()

	log_size = file.get_length()
	if log_size > MAX_UPLOAD_BYTES: file.seek(log_size - MAX_UPLOAD_BYTES)
	var buffer := file.get_buffer(MAX_UPLOAD_BYTES)
	file.close()

	# don't start mid utf-8 sequence; the server decodes strictly
	var start := 0
	while start < 3 and start < buffer.size() and (buffer[start] & 0xC0) == 0x80: start += 1
	return buffer.slice(start) if start > 0 else buffer


func build_log_header(reason: String) -> String:
	var sandboxed: bool = pipe.get("sandboxed", true)
	var uptime := (Time.get_ticks_msec() - start_ms) / 1000.0
	var lines: Array[String] = [
		"=== TheGates renderer crash ===",
		"app_version: %s (%d)" % [AnalyticsEvents.app_version, AnalyticsEvents.app_version_code],
		"os: %s %s" % [OS.get_name(), OS.get_version()],
		"gate: %s" % [gate.url],
		"renderer: %s" % [gate.renderer.get_file()],
		"sandboxed: %s" % [sandboxed],
		"reason: %s" % [reason],
		"uptime_sec: %.1f" % [uptime],
		"first_frame: %s" % [first_frame_reached],
		"process_running: %s" % [renderer_manager.is_process_running()],
		"log_bytes: %d" % [log_size],
		"===============================",
		"",
		"",
	]
	return "\n".join(lines)


func send_logs_request(data: PackedByteArray, length: int) -> void:
	var url = api.send_logs + gate.url.uri_encode()
	var callback = func(_result, code, _headers, _body):
		if code == 200:
			Debug.logclr("Logs were sent %.2fKB" % [length / 1024.0], Color.DIM_GRAY)
		else: Debug.logclr("Sending logs failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request_raw(url, callback, data, HTTPClient.METHOD_POST)
	if err != OK: Debug.logclr("Cannot send request send_logs", Color.RED)

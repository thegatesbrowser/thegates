extends Control

enum ProgressStatus {
	CONNECTING,
	DOWNLOADING,
	STARTING,
	ERROR
}

class DownloadItem:
	var body_size: int
	var downloaded_bytes: int

@export var gate_events: GateEvents
@export var progress_bar_background: Control
@export var progress_bar_error: Control
@export var progress_bar: Control
@export var label: Label

const TWEEN_DURATION_S = 0.2
const SPEED_DELAY_MS = 300
const ZERO_SPEED_DELAY_MS = 2000

var download_items: Dictionary

# For calculating speed
var last_bytes: int
var last_ticks: int
var last_speed: String
var last_is_zero: bool
var first_zero_ticks: int


func _ready() -> void:
	gate_events.gate_info_loaded.connect(on_gate_info_loaded)
	gate_events.gate_entered.connect(on_gate_entered)
	gate_events.gate_error.connect(on_gate_error)
	set_progress("Connecting...", ProgressStatus.CONNECTING)


func on_gate_info_loaded(_gate: Gate) -> void:
	gate_events.download_progress.connect(show_progress)
	last_ticks = Time.get_ticks_msec()


func show_progress(url: String, body_size: int, downloaded_bytes: int) -> void:
	if body_size < 0: return
	
	var item = download_items.get_or_add(url, DownloadItem.new()) as DownloadItem
	item.body_size = body_size
	item.downloaded_bytes = downloaded_bytes
	
	var sum_downloaded_bytes = get_sum(&"downloaded_bytes")
	var sum_body_size = get_sum(&"body_size")
	
	var downloaded = StringTools.bytes_to_string(sum_downloaded_bytes)
	var body = StringTools.bytes_to_string(sum_body_size)
	var speed = get_speed(sum_downloaded_bytes)
	
	var text = "Downloading resources  —  %s of %s (%s/sec)" % [downloaded, body, speed]
	var progress = float(sum_downloaded_bytes) / sum_body_size
	set_progress(text, ProgressStatus.DOWNLOADING, progress)


func get_sum(property: StringName) -> int:
	var result: int = 0
	for item in download_items.values():
		result += item.get(property)
	return result


func get_speed(bytes: int) -> String:
	var delta_bytes = bytes - last_bytes
	var delta_ticks = Time.get_ticks_msec() - last_ticks
	
	if delta_ticks < SPEED_DELAY_MS and not last_speed.is_empty() and not last_is_zero:
		return last_speed
	
	var bytes_sec = 0
	if delta_bytes != 0 and delta_ticks != 0:
		bytes_sec = int(delta_bytes / (delta_ticks / 1000.0))
	
	if should_write_current_speed(bytes_sec):
		last_bytes = bytes
		last_ticks = Time.get_ticks_msec()
		last_speed = StringTools.bytes_to_string(bytes_sec)
	
	return last_speed


func should_write_current_speed(bytes_sec: int) -> bool:
	if last_speed.is_empty():
		last_is_zero = bytes_sec == 0
		return true
	
	if bytes_sec != 0:
		last_is_zero = false
		return true
	
	if not last_is_zero:
		first_zero_ticks = Time.get_ticks_msec()
		last_is_zero = true
		return false
	
	var delta_zero_tiks = Time.get_ticks_msec() - first_zero_ticks
	if delta_zero_tiks < ZERO_SPEED_DELAY_MS:
		return false
	
	return true


func on_gate_entered() -> void:
	gate_events.download_progress.disconnect(show_progress)
	set_progress("Starting the gate...", ProgressStatus.STARTING)


func on_gate_error(code: GateEvents.GateError) -> void:
	match code:
		GateEvents.GateError.NOT_FOUND:
			set_progress("Gate not found", ProgressStatus.ERROR)
		GateEvents.GateError.INVALID_CONFIG:
			set_progress("Gate not found", ProgressStatus.ERROR)
		GateEvents.GateError.MISSING_PACK, GateEvents.GateError.MISSING_LIBS:
			set_progress("Cannot load gate resources", ProgressStatus.ERROR)
		GateEvents.GateError.MISSING_RENDERER:
			set_progress("Cannot load renderer for this gate", ProgressStatus.ERROR)
		_:
			set_progress("Unknown error", ProgressStatus.ERROR)


func set_progress(text: String, status: ProgressStatus, progress: float = 0.0) -> void:
	label.text = text
	
	match status:
		ProgressStatus.CONNECTING:
			progress_bar.show()
			progress_bar_error.hide()
			move_progress_bar(0.0, 0.0)
			
		ProgressStatus.DOWNLOADING:
			progress_bar.show()
			progress_bar_error.hide()
			move_progress_bar(progress, FileDownloader.PROGRESS_DELAY)
			
		ProgressStatus.STARTING:
			progress_bar.show()
			progress_bar_error.hide()
			move_progress_bar(1.0, TWEEN_DURATION_S)
			
		ProgressStatus.ERROR:
			progress_bar.hide()
			progress_bar_error.show()
		
		_:
			progress_bar.hide()
			progress_bar_error.hide()


func move_progress_bar(progress: float, tween_duration: float) -> void:
	var full_size = progress_bar_background.size
	var current_size = Vector2(lerp(0.0, full_size.x, progress), full_size.y)
	
	var tween = get_tree().create_tween()
	tween.tween_property(progress_bar, "size", current_size, tween_duration)

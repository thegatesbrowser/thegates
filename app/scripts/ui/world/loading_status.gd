extends Control

enum ProgressStatus {
	CONNECTING,
	DOWNLOADING,
	STARTING,
	ERROR
}

@export var gate_events: GateEvents
@export var progress_bar_background: Control
@export var progress_bar_error: Control
@export var progress_bar: Control
@export var label: Label

const TWEEN_DURATION_S = 0.2
const SPEED_DELAY_MS = 400
const ZERO_SPEED_DELAY_MS = 2000

var last_bytes: int
var last_ticks: int
var last_speed: String
var last_is_zero: int
var first_zero_ticks: int


func _ready() -> void:
	gate_events.gate_info_loaded.connect(func(_gate, _is_cached): on_gate_info_loaded())
	gate_events.gate_entered.connect(on_gate_entered)
	gate_events.gate_error.connect(on_gate_error)
	set_progress("Connecting...", ProgressStatus.CONNECTING)


func on_gate_info_loaded() -> void:
	gate_events.download_progress.connect(show_progress)


func show_progress(_url: String, body_size: int, downloaded_bytes: int) -> void:
	if body_size < 0: return
	
	var downloaded = bytes_to_string(downloaded_bytes)
	var body = bytes_to_string(body_size)
	var speed = get_speed(downloaded_bytes)
	
	var text = "Downloading resources  —  %s of %s (%s/sec)" % [downloaded, body, speed]
	var progress = float(downloaded_bytes) / body_size
	set_progress(text, ProgressStatus.DOWNLOADING, progress)


func get_speed(bytes: int) -> String:
	var delta_bytes = bytes - last_bytes
	var delta_ticks = Time.get_ticks_msec() - last_ticks
	
	if delta_ticks < SPEED_DELAY_MS and not last_speed.is_empty(): return last_speed
	
	var bytes_sec = 0
	if delta_bytes != 0 and delta_ticks != 0:
		bytes_sec = int(delta_bytes / (delta_ticks / 1000.0))
	
	if should_write_current_speed(bytes_sec):
		last_bytes = bytes
		last_ticks = Time.get_ticks_msec()
		last_speed = bytes_to_string(bytes_sec)
	
	return last_speed


func should_write_current_speed(bytes_sec: int) -> bool:
	if last_speed.is_empty(): return true
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


func bytes_to_string(bytes: int) -> String:
	if bytes < 1024: return str(bytes) + "B"
	
	var kb = bytes / 1024
	if kb < 1024: return str(kb) + "KB"
	
	var mb = kb / 1024.0
	var text = "%.1fMB" if mb < 10.0 else "%.0fMB"
	return text % [mb]


func on_gate_entered() -> void:
	gate_events.download_progress.disconnect(show_progress)
	set_progress("Starting the gate...", ProgressStatus.STARTING)


func on_gate_error(code: GateEvents.GateError) -> void:
	match code:
		GateEvents.GateError.NOT_FOUND:
			set_progress("Gate not found", ProgressStatus.ERROR)
		GateEvents.GateError.INVALID_CONFIG:
			set_progress("Invalid gate config", ProgressStatus.ERROR)
		GateEvents.GateError.MISSING_PACK, GateEvents.GateError.MISSING_LIBS:
			set_progress("Cannot load gate resources", ProgressStatus.ERROR)
		_:
			set_progress("Unknown error", ProgressStatus.ERROR)


func set_progress(text: String, status: ProgressStatus, progress: float = 0.0) -> void:
	label.text = text
	
	match status:
		ProgressStatus.CONNECTING:
			progress_bar.show()
			progress_bar_error.hide()
			move_progress_bar(0.0)
			
		ProgressStatus.DOWNLOADING:
			progress_bar.show()
			progress_bar_error.hide()
			move_progress_bar(progress)
			
		ProgressStatus.STARTING:
			progress_bar.show()
			progress_bar_error.hide()
			move_progress_bar(1.0, true)
			
		ProgressStatus.ERROR:
			progress_bar.hide()
			progress_bar_error.show()
		
		_:
			progress_bar.hide()
			progress_bar_error.hide()


func move_progress_bar(progress: float, custom_delay: bool = false) -> void:
	var full_size = progress_bar_background.size
	var current_size = Vector2(lerp(0.0, full_size.x, progress), full_size.y)
	var tween_duration = TWEEN_DURATION_S if custom_delay else FileDownloader.PROGRESS_DELAY
	
	var tween = get_tree().create_tween()
	tween.tween_property(progress_bar, "size", current_size, tween_duration)

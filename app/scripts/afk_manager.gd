extends Node
#class_name AfkManager

signal state_changed(is_afk: bool)

const AFK_TIMEOUT_SEC = 180

var afk_check_timer: Timer

var session_start_tick: int
var last_key_tick: int
var cumulative_afk_msec: int
var afk_start_tick: int


func _ready() -> void:
	session_start_tick = Time.get_ticks_msec()
	last_key_tick = session_start_tick

	afk_check_timer = Timer.new()
	afk_check_timer.one_shot = false
	afk_check_timer.wait_time = 1.0
	add_child(afk_check_timer)
	
	afk_check_timer.timeout.connect(check_afk)
	afk_check_timer.start()


func _input(_event: InputEvent) -> void:
	var now := Time.get_ticks_msec()
	last_key_tick = now
	if afk_start_tick != 0:
		leave_afk(now)


func check_afk() -> void:
	var now := Time.get_ticks_msec()
	if afk_start_tick == 0 and now - last_key_tick >= AFK_TIMEOUT_SEC * 1000:
		enter_afk(now)


func enter_afk(now: int) -> void:
	afk_start_tick = now
	state_changed.emit(true)


func leave_afk(now: int) -> void:
	if afk_start_tick == 0:
		return
	
	cumulative_afk_msec += now - afk_start_tick
	afk_start_tick = 0
	state_changed.emit(false)


func get_active_sec() -> float:
	var now := Time.get_ticks_msec()
	var afk_current := (now - afk_start_tick) if afk_start_tick != 0 else 0
	var active_msec := (now - session_start_tick) - cumulative_afk_msec - afk_current
	return max(0.0, float(active_msec) / 1000.0)

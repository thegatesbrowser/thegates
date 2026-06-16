extends Node
#class_name AfkManager

signal state_changed(is_afk: bool)

const AFK_TIMEOUT_MSEC := 180 * 1000
const TICK_SEC := 1.0

var tick_timer: Timer

var last_input_msec: int
var active_sec: float
var is_afk: bool


func _ready() -> void:
	last_input_msec = Time.get_ticks_msec()

	tick_timer = Timer.new()
	tick_timer.wait_time = TICK_SEC
	add_child(tick_timer)
	tick_timer.timeout.connect(on_tick)
	tick_timer.start()


func _input(_event: InputEvent) -> void:
	last_input_msec = Time.get_ticks_msec()
	if is_afk:
		leave_afk()


# only runs while active (timer is stopped on afk); a stalled app just stops ticking
func on_tick() -> void:
	if Time.get_ticks_msec() - last_input_msec >= AFK_TIMEOUT_MSEC:
		enter_afk()
		return
	active_sec += TICK_SEC


func enter_afk() -> void:
	is_afk = true
	tick_timer.stop()
	state_changed.emit(true)


func leave_afk() -> void:
	is_afk = false
	tick_timer.start()
	state_changed.emit(false)


func get_active_sec() -> float:
	return active_sec

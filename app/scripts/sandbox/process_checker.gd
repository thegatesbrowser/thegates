extends Node

@export var gate_events: GateEvents
@export var command_events: CommandEvents
@export var snbx_logger: SandboxLogger

# Timeout intervals for child process responsiveness
const BOOTUP_CHECK_SEC = 1
const BOOTUP_INTERVAL_MSEC = 5000
const HEARTBEAT_INTERVAL_SEC = 5
const WAIT_INTERVAL_SEC = 15

var bootup_timer: Timer
var heartbeat_timer: Timer


func _ready() -> void:
	bootup_timer = Timer.new()
	heartbeat_timer = Timer.new()
	add_child(bootup_timer)
	add_child(heartbeat_timer)
	
	bootup_timer.timeout.connect(bootup_check)
	heartbeat_timer.timeout.connect(on_timeout)
	
	gate_events.gate_entered.connect(start_bootup_check)
	gate_events.first_frame.connect(start_heartbeat_timer)
	command_events.heartbeat.connect(restart_heartbeat_timer)


func start_bootup_check() -> void:
	bootup_timer.start(BOOTUP_CHECK_SEC)


func bootup_check() -> void:
	var interval = Time.get_ticks_msec() - snbx_logger.last_log_tick
	if interval < BOOTUP_INTERVAL_MSEC: return
	
	bootup_timer.stop()
	on_timeout()


func start_heartbeat_timer() -> void:
	if not bootup_timer.is_stopped(): bootup_timer.stop()
	heartbeat_timer.start(HEARTBEAT_INTERVAL_SEC)


func restart_heartbeat_timer() -> void:
	heartbeat_timer.start(HEARTBEAT_INTERVAL_SEC)


func on_timeout() -> void:
	Debug.logerr("Gate is not responding")
	gate_events.not_responding_emit()
	heartbeat_timer.start(WAIT_INTERVAL_SEC)

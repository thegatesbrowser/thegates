extends Node

@export var gate_events: GateEvents
@export var command_events: CommandEvents

# Timeout interval for child process responsiveness
const BOOTUP_INTERVAL = 30
const HEARTBEAT_INTERVAL = 5
const WAIT_INTERVAL = 30

var timer: Timer


func _ready() -> void:
	timer = Timer.new()
	add_child(timer)
	timer.timeout.connect(on_timeout)
	
	gate_events.gate_entered.connect(start_bootup_timer)
	command_events.heartbeat.connect(restart_heartbeat_timer)


func start_bootup_timer() -> void:
	timer.start(BOOTUP_INTERVAL)


func restart_heartbeat_timer() -> void:
	timer.start(HEARTBEAT_INTERVAL)


func on_timeout() -> void:
	Debug.logerr("Gate is not responding")
	gate_events.not_responding_emit()
	timer.start(WAIT_INTERVAL)

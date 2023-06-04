extends Node
class_name AnalyticsSenderGate

var gate_events := preload("res://the_gates/resources/gate_events.res")

var gate_open_time: int
var gate_url: String


func _ready() -> void:
	gate_events.open_gate.connect(send_gate_open)
	gate_events.gate_entered.connect(send_gate_enter)
	gate_events.exit_gate.connect(send_gate_exit)


func send_gate_open(url: String) -> void:
	gate_url = url
	gate_open_time = int(Time.get_ticks_msec() / 1000)
	Analytics.send_event(AnalyticsEvents.gate_open(url))


func send_gate_enter() -> void:
	var download_time = int(Time.get_ticks_msec() / 1000) - gate_open_time
	gate_open_time = int(Time.get_ticks_msec() / 1000)
	Analytics.send_event(AnalyticsEvents.gate_enter(gate_url, download_time))


func send_gate_exit() -> void:
	var time_spend = int(Time.get_ticks_msec() / 1000) - gate_open_time
	Analytics.send_event(AnalyticsEvents.gate_exit(gate_url, time_spend))
	gate_url = ""


func exit() -> void:
	if gate_url.is_empty(): return
	send_gate_exit()

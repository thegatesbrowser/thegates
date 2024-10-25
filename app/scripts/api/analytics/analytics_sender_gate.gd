extends AnalyticsSender
class_name AnalyticsSenderGate

@export var gate_events: GateEvents

var gate_open_tick: int
var gate_enter_tick: int
var gate_url: String


func start() -> void:
	super.start()
	
	gate_events.search.connect(send_search)
	gate_events.open_gate.connect(send_gate_open)
	gate_events.gate_entered.connect(send_gate_enter)
	gate_events.first_frame.connect(send_first_frame)
	gate_events.exit_gate.connect(send_gate_exit)
	
	# Send latest exit event
	var json: String = DataSaver.get_string("analytics", "send_gate_exit")
	if json.is_empty(): return
	DataSaver.set_value("analytics", "send_gate_exit", "")
	analytics.send_event(JSON.parse_string(json))


func send_search(query: String) -> void:
	send_gate_exit()
	
	analytics.send_event(AnalyticsEvents.search(query))


func send_gate_open(url: String) -> void:
	send_gate_exit()
	
	gate_url = url
	gate_open_tick = Time.get_ticks_msec()
	analytics.send_event(AnalyticsEvents.gate_open(url))


func send_gate_enter() -> void:
	var download_time = get_delta_sec(gate_open_tick)
	gate_enter_tick = Time.get_ticks_msec()
	analytics.send_event(AnalyticsEvents.gate_enter(gate_url, download_time))


func send_first_frame() -> void:
	var loading_time = get_delta_sec(gate_enter_tick)
	analytics.send_event(AnalyticsEvents.first_frame(gate_url, loading_time))


func send_gate_exit() -> void:
	if gate_url.is_empty(): return
	
	var time_spend = get_delta_sec(gate_open_tick)
	analytics.send_event(AnalyticsEvents.gate_exit(gate_url, time_spend))
	gate_url = ""


func _exit_tree() -> void:
	if gate_url.is_empty(): return
	
	# Save to send on open
	var time_spend = get_delta_sec(gate_open_tick)
	var event = AnalyticsEvents.gate_exit(gate_url, time_spend)
	DataSaver.set_value("analytics", "send_gate_exit", JSON.stringify(event))


func get_delta_sec(from_msec: int) -> float:
	return float(Time.get_ticks_msec() - from_msec) / 1000

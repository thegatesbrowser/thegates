extends AnalyticsSender
class_name AnalyticsSenderGate

@export var gate_events: GateEvents

var gate_open_time: int
var gate_url: String


func start() -> void:
	super.start()
	
	gate_events.search.connect(send_search)
	gate_events.open_gate.connect(send_gate_open)
	gate_events.gate_entered.connect(send_gate_enter)
	gate_events.exit_gate.connect(send_gate_exit)
	
	# Send latest exit event
	var json: String = DataSaver.get_string("analytics", "send_gate_exit")
	if json.is_empty(): return
	DataSaver.set_value("analytics", "send_gate_exit", "")
	analytics.send_event(JSON.parse_string(json))


func send_search(query: String) -> void:
	if not gate_url.is_empty(): send_gate_exit()
	
	analytics.send_event(AnalyticsEvents.search(query))


func send_gate_open(url: String) -> void:
	if not gate_url.is_empty(): send_gate_exit()
	
	gate_url = url
	gate_open_time = int(Time.get_ticks_msec() / 1000)
	analytics.send_event(AnalyticsEvents.gate_open(url))


func send_gate_enter() -> void:
	var download_time = int(Time.get_ticks_msec() / 1000) - gate_open_time
	gate_open_time = int(Time.get_ticks_msec() / 1000)
	analytics.send_event(AnalyticsEvents.gate_enter(gate_url, download_time))


func send_gate_exit() -> void:
	if gate_url.is_empty(): return
	
	var time_spend = int(Time.get_ticks_msec() / 1000) - gate_open_time
	analytics.send_event(AnalyticsEvents.gate_exit(gate_url, time_spend))
	gate_url = ""


func _exit_tree() -> void:
	if gate_url.is_empty(): return
	
	# Save to send on open
	var time_spend = int(Time.get_ticks_msec() / 1000) - gate_open_time
	var event = AnalyticsEvents.gate_exit(gate_url, time_spend)
	DataSaver.set_value("analytics", "send_gate_exit", JSON.stringify(event))

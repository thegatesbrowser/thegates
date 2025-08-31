extends AnalyticsSender
class_name AnalyticsSenderGate

@export var gate_events: GateEvents

var gate_open_tick: int
var gate_load_tick: int
var gate_url: String


func start() -> void:
	super.start()
	
	# Send latest exit event
	var json: String = DataSaver.get_string("analytics", "send_gate_exit")
	if json.is_empty(): return
	DataSaver.set_value("analytics", "send_gate_exit", "")
	analytics.send_event(JSON.parse_string(json))
	
	gate_events.search.connect(send_search)
	gate_events.open_gate.connect(send_gate_open)
	gate_events.gate_loaded.connect(func(_gate): send_gate_load())
	gate_events.first_frame.connect(send_gate_start)
	gate_events.exit_gate.connect(send_gate_exit)


func send_search(query: String) -> void:
	send_gate_exit()
	
	analytics.send_event(AnalyticsEvents.search(query))


func send_gate_open(url: String) -> void:
	send_gate_exit()
	
	gate_url = url
	gate_open_tick = Time.get_ticks_msec()
	analytics.send_event(AnalyticsEvents.gate_open(url))


func send_gate_load() -> void:
	var download_time = Analytics.get_delta_sec_from_tick(gate_open_tick)
	gate_load_tick = Time.get_ticks_msec()
	analytics.send_event(AnalyticsEvents.gate_load(gate_url, download_time))
	Debug.logclr("Download time: %.3f" % [download_time], Color.AQUAMARINE)


func send_gate_start() -> void:
	var bootup_time = Analytics.get_delta_sec_from_tick(gate_load_tick)
	analytics.send_event(AnalyticsEvents.gate_start(gate_url, bootup_time))
	Debug.logclr("Bootup time: %.3f" % [bootup_time], Color.AQUAMARINE)


func send_gate_exit() -> void:
	if gate_url.is_empty(): return
	
	var time_spent = Analytics.get_delta_sec_from_tick(gate_open_tick)
	analytics.send_event(AnalyticsEvents.gate_exit(gate_url, time_spent))
	gate_url = ""


func _exit_tree() -> void:
	if gate_url.is_empty(): return
	
	# Save to send on open
	var time_spent = Analytics.get_delta_sec_from_tick(gate_open_tick)
	var event = AnalyticsEvents.gate_exit(gate_url, time_spent)
	DataSaver.set_value("analytics", "send_gate_exit", JSON.stringify(event))

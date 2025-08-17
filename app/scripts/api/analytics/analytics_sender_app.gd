extends AnalyticsSender
class_name AnalyticsSenderApp

const HEARTBEAT_DELAY = 60

var heartbeat_timer: Timer


func start() -> void:
	super.start()
	
	analytics.send_event(AnalyticsEvents.app_open())
	
	start_heartbeat()
	AfkManager.state_changed.connect(on_state_changed)
	
	# Send latest exit event
	var json: String = DataSaver.get_string("analytics", "app_exit")
	if json.is_empty(): return
	DataSaver.set_value("analytics", "app_exit", "")
	analytics.send_event(JSON.parse_string(json))


func start_heartbeat() -> void:
	heartbeat_timer = Timer.new()
	add_child(heartbeat_timer)
	heartbeat_timer.timeout.connect(send_hearbeat)
	heartbeat_timer.start(HEARTBEAT_DELAY)


func send_hearbeat() -> void:
	var time_spent = AfkManager.get_active_sec()
	analytics.send_event(AnalyticsEvents.heartbeat(time_spent))


func on_state_changed(is_afk: bool) -> void:
	if is_afk:
		heartbeat_timer.stop()
		return
	
	heartbeat_timer.start(HEARTBEAT_DELAY)


func _exit_tree() -> void:
	# Save to send on open
	var time_spent = AfkManager.get_active_sec()
	var event = AnalyticsEvents.app_exit(time_spent)
	DataSaver.set_value("analytics", "app_exit", JSON.stringify(event))

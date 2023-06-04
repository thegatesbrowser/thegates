extends Node
class_name AnalyticsSenderApp

const HEARTBEAT_DELAY = 60
var heartbeat_timer: Timer


func _ready() -> void:
	Analytics.send_event(AnalyticsEvents.app_open())
	start_heartbeat()


func start_heartbeat() -> void:
	heartbeat_timer = Timer.new()
	add_child(heartbeat_timer)
	heartbeat_timer.timeout.connect(send_hearbeat)
	heartbeat_timer.start(HEARTBEAT_DELAY)


func send_hearbeat() -> void:
	var time_spend = int(Time.get_ticks_msec() / 1000)
	Analytics.send_event(AnalyticsEvents.heartbeat(time_spend))


func exit() -> void:
	var time_spend = int(Time.get_ticks_msec() / 1000)
	Analytics.send_event(AnalyticsEvents.app_exit(time_spend))

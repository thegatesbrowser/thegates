extends AnalyticsSender
class_name AnalyticsSenderAfk

var afk_started_tick: int


func start() -> void:
	super.start()
	
	AfkManager.state_changed.connect(send_afk_state_changed)


func send_afk_state_changed(is_afk: bool) -> void:
	if is_afk:
		afk_started_tick = Time.get_ticks_msec()
		analytics.send_event(AnalyticsEvents.enter_afk())
	else:
		var time_spent = Analytics.get_delta_sec_from_tick(afk_started_tick)
		analytics.send_event(AnalyticsEvents.leave_afk(time_spent))

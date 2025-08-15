extends AnalyticsSender
class_name AnalyticsSenderOnboarding

@export var ui_events: UiEvents

var onboarding_started_tick: int


func start() -> void:
	super.start()
	
	ui_events.onboarding_started.connect(send_onboarding_started)
	ui_events.onboarding_finished.connect(send_onboarding_finished)
	
	if ui_events.is_onboarding_started:
		send_onboarding_started()


func send_onboarding_started() -> void:
	onboarding_started_tick = Time.get_ticks_msec()
	analytics.send_event(AnalyticsEvents.onboarding_started())


func send_onboarding_finished() -> void:
	var time_spend = Analytics.get_delta_sec_from_tick(onboarding_started_tick)
	analytics.send_event(AnalyticsEvents.onboarding_finished(time_spend))

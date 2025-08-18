extends AnalyticsSender
class_name AnalyticsSenderLink

@export var app_events: AppEvents


func start() -> void:
	super.start()
	
	app_events.open_link.connect(send_open_link)


func send_open_link(url: String) -> void:
	analytics.send_event(AnalyticsEvents.open_link(url))

extends AnalyticsSender
class_name AnalyticsSenderError


func start() -> void:
	super.start()
	
	Debug.error.connect(send_error)


func send_error(msg: String) -> void:
	analytics.send_event(AnalyticsEvents.error(msg))

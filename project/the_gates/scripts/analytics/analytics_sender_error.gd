extends Node
class_name AnalyticsSenderError


func _ready() -> void:
	Debug.error.connect(send_error)


func send_error(msg: String) -> void:
	Analytics.send_event(AnalyticsEvents.error(msg))

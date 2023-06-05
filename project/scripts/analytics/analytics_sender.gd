extends Node
class_name AnalyticsSender

var analytics: Analitycs


func _enter_tree() -> void:
	analytics = get_parent()
	analytics.analytics_ready.connect(start)


func start() -> void:
	pass

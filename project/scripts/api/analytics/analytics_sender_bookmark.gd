extends AnalyticsSender
class_name AnalyticsSenderBookmark

@export var bookmarks: Bookmarks


func _ready() -> void:
	super.start()
	
	bookmarks.on_star.connect(send_bookmark)
	bookmarks.on_unstar.connect(send_unbookmark)


func send_bookmark(gate: Gate):
	analytics.send_event(AnalyticsEvents.bookmark(gate.url))


func send_unbookmark(gate: Gate):
	analytics.send_event(AnalyticsEvents.unbookmark(gate.url))

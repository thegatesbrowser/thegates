extends Label

@export var gate_events: GateEvents
@export var header: String


func _ready() -> void:
	text = "%s \"%s\"" % [header, gate_events.current_search_query]

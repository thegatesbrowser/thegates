extends Label
class_name SearchResultsHeader

@export var gate_events: GateEvents
@export var search_header: String
@export var suggestion_header: String


func set_search_header() -> void:
	text = "%s \"%s\"" % [search_header, gate_events.current_search_query]


func set_suggestion_header() -> void:
	text = suggestion_header

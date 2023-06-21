extends VBoxContainer

@export var gate_events: GateEvents


func _ready() -> void:
	search(gate_events.current_search_query)


func search(query: String) -> void:
	Debug.logclr("======== " + query + " ========", Color.LIGHT_SEA_GREEN)

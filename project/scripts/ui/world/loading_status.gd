extends Label

@export var gate_events: GateEvents


func _ready() -> void:
	gate_events.gate_info_loaded.connect(func(_gate): on_gate_info_loaded())
	gate_events.gate_entered.connect(on_gate_entered)


func on_gate_info_loaded() -> void:
	text = "Downloading files..."


func on_gate_entered() -> void:
	text = ""

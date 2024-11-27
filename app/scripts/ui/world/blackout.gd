extends Panel

@export var gate_events: GateEvents


func _ready() -> void:
	gate_events.first_frame.connect(func(): visible = true)

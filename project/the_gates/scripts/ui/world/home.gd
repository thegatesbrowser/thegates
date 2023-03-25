extends BaseButton

@export var gate_events: GateEvents


func _on_pressed() -> void:
	gate_events.exit_gate_emit()

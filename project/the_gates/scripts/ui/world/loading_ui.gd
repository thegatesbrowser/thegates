extends Control

@export var gate_events: GateEvents


func _ready() -> void:
	gate_events.gate_entered.connect(hide_ui)
	visible = true


func hide_ui() -> void:
	visible = false

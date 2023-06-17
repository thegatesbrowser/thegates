extends AnimationPlayer

@export var ui_events: UiEvents
@export var gate_events: GateEvents

const RESET := "RESET"
const INITIAL := "initial"
const FULLSCREEN := "fullscreen"

var fullscreen := false


func _ready() -> void:
	ui_events.visibility_changed.connect(on_visibility_changed)
	gate_events.open_gate.connect(func(_url): on_visibility_changed(true))


func on_visibility_changed(visible: bool) -> void:
	if visible and fullscreen:
		fullscreen = false
		play(INITIAL)
	
	if not visible and not fullscreen:
		fullscreen = true
		play(FULLSCREEN)

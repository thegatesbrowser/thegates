extends AnimationPlayer

@export var ui_events: UiEvents
@export var gate_events: GateEvents

const RESET := "RESET"
const INITIAL := "initial"
const FULLSCREEN := "fullscreen"

var fullscreen := false


func _ready() -> void:
	ui_events.ui_mode_changed.connect(on_ui_mode_changed)
	gate_events.open_gate.connect(func(_url): on_ui_mode_changed(UiEvents.UiMode.INITIAL))


func on_ui_mode_changed(mode: UiEvents.UiMode) -> void:
	if mode == UiEvents.UiMode.INITIAL and fullscreen:
		fullscreen = false
		play(INITIAL)
	
	if mode == UiEvents.UiMode.FULL_SCREEN and not fullscreen:
		fullscreen = true
		play(FULLSCREEN)

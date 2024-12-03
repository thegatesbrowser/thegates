extends AnimationPlayer

@export var ui_events: UiEvents
@export var gate_events: GateEvents

const RESET := "RESET"
const INITIAL := "initial"
const FOCUSED := "focused"

var focused := false


func _ready() -> void:
	ui_events.ui_mode_changed.connect(on_ui_mode_changed)
	gate_events.open_gate.connect(func(_url): on_ui_mode_changed(UiEvents.UiMode.INITIAL))


func on_ui_mode_changed(mode: UiEvents.UiMode) -> void:
	if mode == UiEvents.UiMode.INITIAL and focused:
		focused = false
		play(INITIAL)
	
	if mode == UiEvents.UiMode.FOCUSED and not focused:
		focused = true
		play(FOCUSED)

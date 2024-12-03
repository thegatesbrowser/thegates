extends Control

@export var gate_events: GateEvents
@export var ui_events: UiEvents
@export var splash_screen: TextureRect
@export var vignette_blur: VignetteBlur
@export var click_anywhere: Control


func _ready() -> void:
	gate_events.gate_info_loaded.connect(show_thumbnail)
	gate_events.first_frame.connect(on_first_frame)
	ui_events.ui_mode_changed.connect(on_ui_mode_changed)
	vignette_blur.hide()
	click_anywhere.hide()


func show_thumbnail(gate: Gate, _is_cached: bool) -> void:
	splash_screen.texture = FileTools.load_external_tex(gate.image)
	vignette_blur.show()
	vignette_blur.thumbnail_params()


func on_first_frame() -> void:
	splash_screen.hide()
	click_anywhere.show()
	vignette_blur.gate_started_params()


func on_ui_mode_changed(mode: UiEvents.UiMode) -> void:
	if mode == UiEvents.UiMode.INITIAL:
		show()
	
	if mode == UiEvents.UiMode.FOCUSED:
		click_anywhere.hide()
		hide()

extends Control

@export var gate_events: GateEvents
@export var ui_events: UiEvents
@export var splash_screen: TextureRect
@export var vignette_blur: VignetteBlur


func _ready() -> void:
	vignette_blur.hide()
	
	gate_events.call_or_subscribe(GateEvents.Early.IMAGE_LOADED, show_thumbnail)
	gate_events.first_frame.connect(on_first_frame)
	ui_events.ui_mode_changed.connect(on_ui_mode_changed)


func show_thumbnail(gate: Gate) -> void:
	splash_screen.texture = FileTools.load_external_tex(gate.image)
	if not is_instance_valid(splash_screen.texture): return
	vignette_blur.show()
	vignette_blur.thumbnail_params()


func on_first_frame() -> void:
	splash_screen.hide()
	vignette_blur.show()
	vignette_blur.gate_started_params()


func on_ui_mode_changed(mode: UiEvents.UiMode) -> void:
	if mode == UiEvents.UiMode.INITIAL:
		show()
	
	if mode == UiEvents.UiMode.FOCUSED:
		hide()

extends TextureRect
class_name SplashScreen

@export var gate_events: GateEvents
@export var command_events: CommandEvents
@export var ui_events: UiEvents
@export var render_result: RenderResult


func _ready():
	gate_events.gate_info_loaded.connect(show_thumbnail)
	#gate_events.first_frame.connect(func(): hide())


func show_thumbnail(gate: Gate, _is_cached: bool) -> void:
	#if is_cached: return # Resource pack is already downloaded
	texture = FileTools.load_external_tex(gate.image)

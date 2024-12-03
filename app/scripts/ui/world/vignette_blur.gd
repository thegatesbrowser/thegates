extends Control
class_name VignetteBlur

const BLUR_AMOUNT = "BlurAmount"
const UV_SCALE = "UVScale"

@export var blur_amount_game: float
@export var uv_scale: Vector2


func gate_started_params() -> void:
	set_param(BLUR_AMOUNT, blur_amount_game)
	set_param(UV_SCALE, uv_scale)


func set_param(param: StringName, value: Variant) -> void:
	(material as ShaderMaterial).set_shader_parameter(param, value)

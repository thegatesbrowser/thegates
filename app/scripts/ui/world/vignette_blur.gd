extends Control
class_name VignetteBlur

const BLUR_AMOUNT = "BlurAmount"
const UV_SCALE = "UVScale"

@export var blur_amount: float
@export var blur_amount_started: float
@export var uv_scale: Vector2
@export var uv_scale_startd: Vector2


func thumbnail_params() -> void:
	set_param(BLUR_AMOUNT, blur_amount)
	set_param(UV_SCALE, uv_scale)


func gate_started_params() -> void:
	set_param(BLUR_AMOUNT, blur_amount_started)
	set_param(UV_SCALE, uv_scale_startd)


func set_param(param: StringName, value: Variant) -> void:
	(material as ShaderMaterial).set_shader_parameter(param, value)

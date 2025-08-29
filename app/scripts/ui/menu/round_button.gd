extends Button
class_name RoundButton

@export var gate_events: GateEvents
@export var command_events: CommandEvents
@export var special_effect: Panel

var button_id: String
var is_highlighted: bool


func _ready() -> void:
	if disabled: disable()
	else: enable()
	
	button_id = name.to_lower()
	special_effect.visible = false
	command_events.highlight_button.connect(highlight)


func disable() -> void:
	disabled = true
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	unhighlight()


func enable() -> void:
	disabled = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	unhighlight()


func highlight(_button_id: String) -> void:
	if disabled or is_highlighted: return
	if button_id != _button_id: return
	if not Url.is_trusted_url(gate_events.current_gate_url): return
	
	special_effect.visible = true
	is_highlighted = true
	
	pressed.connect(unhighlight)
	gate_events.search.connect(unhighlight)
	gate_events.open_gate.connect(unhighlight)
	gate_events.exit_gate.connect(unhighlight)


func unhighlight(_unbind: String = "") -> void:
	if not is_highlighted: return
	
	special_effect.visible = false
	is_highlighted = false
	
	pressed.disconnect(unhighlight)
	gate_events.search.disconnect(unhighlight)
	gate_events.open_gate.disconnect(unhighlight)
	gate_events.exit_gate.disconnect(unhighlight)

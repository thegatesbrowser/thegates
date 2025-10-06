extends NotifierBase

const SECTION: String = "notifications"
const KEY: String = "mouse_mode_restored"

@export var ui_events: UiEvents
@export var show_delay_sec: float = 3.0
@export var hide_delay_sec: float = 0.05

var last_mode: Input.MouseMode
var is_showing: bool
var is_restored: bool
var scheduled_action_sequence: int = 0


func _ready() -> void:
	is_restored = DataSaver.get_value(SECTION, KEY, false)
	if is_restored: return
	
	ui_events.mouse_mode_changed.connect(on_mouse_mode_changed)


func _input(event: InputEvent) -> void:
	if not is_showing or is_restored: return
	
	if event.is_action_pressed("show_ui"):
		is_restored = true
		DataSaver.set_value(SECTION, KEY, true)
		DataSaver.save_data()


func on_mouse_mode_changed(mode: Input.MouseMode) -> void:
	if is_restored or last_mode == mode: return
	last_mode = mode
	
	if mode == Input.MOUSE_MODE_VISIBLE:
		schedule_hide_with_delay()
	else:
		schedule_show_with_delay()


func schedule_show_with_delay() -> void:
	scheduled_action_sequence += 1
	var action_id: int = scheduled_action_sequence
	await get_tree().create_timer(show_delay_sec).timeout
	
	if action_id != scheduled_action_sequence: return
	if is_showing: return
	is_showing = true
	
	show_notification()


func schedule_hide_with_delay() -> void:
	scheduled_action_sequence += 1
	var action_id: int = scheduled_action_sequence
	await get_tree().create_timer(hide_delay_sec).timeout
	
	if action_id != scheduled_action_sequence: return
	if not is_showing: return
	is_showing = false
	
	hide_notification()

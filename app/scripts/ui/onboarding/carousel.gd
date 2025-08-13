extends Control

@export var ui_events: UiEvents
@export var line: Control
@export var close: Button

@export var tween_duration: float = 0.3
@export var drag_deadzone: float = 20.0
@export var page_switch_threshold: float = 75.0
@export var overscroll_softness: float = 30.0
@export var overscroll_limit: float = 200.0

var boards: Array[OnboardingBoard] = []
var focused_page: int
var tween: Tween

var dragging: bool
var drag_started: bool
var drag_start_position: Vector2
var drag_start_line_x: float
var last_mouse_position: Vector2


func _ready() -> void:
	setup_boards()
	assert(boards.size() > 0, "Carousel must have at least one board")
	
	ui_events.ui_size_changed.connect(on_ui_size_changed)
	move_line(0)


func setup_boards() -> void:
	for child in line.get_children():
		if child is not OnboardingBoard: continue
		boards.append(child)
	
	for i in range(boards.size()):
		boards[i].request_focus.connect(move_line.bind(i))


func on_ui_size_changed(ui_size: Vector2) -> void:
	var screen_center = ui_size.y / 2
	line.position.y = screen_center - line.size.y / 2
	
	move_line(focused_page)


func move_line(board_index: int) -> void:
	var board = boards[board_index]
	focused_page = board_index
	
	var screen_center = ui_events.current_ui_size.x / 2
	var wanted_board_position = screen_center - board.size.x / 2
	var line_position = Vector2(wanted_board_position - board.position.x, line.position.y)
	
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.tween_property(line, "position", line_position, tween_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	for i in range(boards.size()):
		if i == board_index:
			boards[i].focus(tween_duration)
		else: boards[i].unfocus(tween_duration)
	
	await tween.finished
	refresh_mouse_position()


func refresh_mouse_position() -> void:
	var event = InputEventMouseMotion.new()
	event.position = get_viewport().get_mouse_position()
	Input.parse_input_event(event)


func set_focus_buttons_disabled(disabled: bool) -> void:
	close.disabled = disabled
	for board in boards:
		board.focus_button.disabled = disabled


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start dragging
			dragging = true
			drag_started = false
			drag_start_position = event.position
			last_mouse_position = event.position
			drag_start_line_x = line.position.x
		else:
			# End dragging
			if dragging:
				dragging = false
				if not drag_started:
					# Treat as click: if no tween is playing, keep current focused page
					if not (is_instance_valid(tween) and tween.is_running()):
						move_line(focused_page)
					return
				
				# Drag was active: consume release and re-enable focus buttons
				set_focus_buttons_disabled(false)
				accept_event()
				
				# Decide target page based on drag distance/direction
				var total_drag_x: float = event.position.x - drag_start_position.x
				var last_index: int = boards.size() - 1
				var target_index: int = focused_page
				
				if abs(total_drag_x) >= page_switch_threshold:
					if total_drag_x < 0.0:
						target_index = min(focused_page + 1, last_index)
					else:
						target_index = max(focused_page - 1, 0)
				
				move_line(target_index)
	
	elif event is InputEventMouseMotion:
		if dragging:
			var delta_x: float = event.position.x - last_mouse_position.x
			if not drag_started:
				var moved_enough: bool = abs(event.position.x - drag_start_position.x) >= drag_deadzone
				if moved_enough:
					drag_started = true
					# Now that drag truly started, stop any ongoing tween
					if is_instance_valid(tween): tween.stop()
					set_focus_buttons_disabled(true)
					accept_event()
			
			if drag_started:
				var displacement: float = abs(line.position.x - drag_start_line_x)
				var resistance: float = 1.0 / (1.0 + displacement / overscroll_softness)
				var applied_dx: float = delta_x * resistance
				var new_x: float = line.position.x + applied_dx
				var delta_from_start: float = new_x - drag_start_line_x
				
				if delta_from_start > overscroll_limit:
					new_x = drag_start_line_x + overscroll_limit
				elif delta_from_start < -overscroll_limit:
					new_x = drag_start_line_x - overscroll_limit
				
				line.position.x = new_x
			
			last_mouse_position = event.position
			
			if drag_started:
				accept_event()

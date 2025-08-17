extends Control

@export var ui_events: UiEvents
@export var line: Control
@export var close: Button

@export var tween_duration: float = 0.3
@export var drag_deadzone: float = 20.0
@export var board_switch_threshold: float = 50.0
@export var overscroll_softness: float = 30.0
@export var overscroll_limit: float = 200.0

var boards: Array[OnboardingBoard] = []
var current_board: int
var tween: Tween

var dragging: bool
var drag_started: bool
var drag_start_position: Vector2
var drag_start_line_x: float
var last_mouse_position: Vector2


func _ready() -> void:
	collect_boards()
	assert(boards.size() > 0, "Carousel must have at least one board")
	
	ui_events.ui_size_changed.connect(on_ui_size_changed)
	animate_to_board(0)


func collect_boards() -> void:
	for child in line.get_children():
		if child is not OnboardingBoard: continue
		boards.append(child)
	
	for i in range(boards.size()):
		boards[i].request_focus.connect(animate_to_board.bind(i))


func on_ui_size_changed(ui_size: Vector2) -> void:
	var screen_center = ui_size.y / 2
	line.position.y = screen_center - line.size.y / 2
	
	animate_to_board(current_board)


func animate_to_board(board_index: int) -> void:
	board_index = clamp(board_index, 0, boards.size() - 1)
	current_board = board_index
	
	var target_position := compute_line_position_for_board(board_index)
	
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.tween_property(line, "position", target_position, tween_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	for i in range(boards.size()):
		if i == board_index:
			boards[i].focus(tween_duration)
		else:
			boards[i].unfocus(tween_duration)
	
	await tween.finished
	refresh_mouse_position()


func compute_line_position_for_board(board_index: int) -> Vector2:
	var board := boards[board_index]
	var screen_center_x := ui_events.current_ui_size.x / 2.0
	var wanted_board_position := screen_center_x - board.size.x / 2.0
	return Vector2(wanted_board_position - board.position.x, line.position.y)


func refresh_mouse_position() -> void:
	var event = InputEventMouseMotion.new()
	event.position = get_viewport().get_mouse_position()
	Input.parse_input_event(event)


# DRAGGING

func set_buttons_disabled(disabled: bool) -> void:
	close.disabled = disabled
	for board in boards:
		board.focus_button.disabled = disabled


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			begin_drag(event.position)
		elif dragging:
			end_drag()
	
	if event is InputEventMouseMotion and dragging:
		if not drag_started:
			var moved_enough: bool = abs(event.position.x - drag_start_position.x) >= drag_deadzone
			
			if moved_enough:
				drag_started = true
				
				if is_instance_valid(tween):
					tween.stop()
				
				set_buttons_disabled(true)
				accept_event()
		
		if drag_started:
			var delta_x: float = event.position.x - last_mouse_position.x
			apply_drag(delta_x)
			accept_event()
		
		last_mouse_position = event.position


func begin_drag(mouse_pos: Vector2) -> void:
	dragging = true
	drag_started = false
	drag_start_position = mouse_pos
	last_mouse_position = mouse_pos
	drag_start_line_x = line.position.x


func end_drag() -> void:
	dragging = false
	
	if not drag_started:
		# Treat as click, keep current board
		if not (is_instance_valid(tween) and tween.is_running()):
			animate_to_board(current_board)
		return
	
	set_buttons_disabled(false)
	accept_event()
	
	var line_delta_x := line.position.x - drag_start_line_x
	var target_index := determine_target_board(line_delta_x)
	animate_to_board(target_index)


func determine_target_board(line_delta_x: float) -> int:
	if abs(line_delta_x) < board_switch_threshold:
		return current_board
	
	if line_delta_x < 0.0:
		return min(current_board + 1, boards.size() - 1)
	else:
		return max(current_board - 1, 0)


func apply_drag(delta_x: float) -> void:
	# Scale input movement by resistance that grows with displacement
	var displacement: float = abs(line.position.x - drag_start_line_x)
	var resistance: float = 1.0 / (1.0 + displacement / overscroll_softness)
	var applied_dx: float = delta_x * resistance
	
	var new_x: float = line.position.x + applied_dx
	
	# Prevent overscroll
	var delta_from_start: float = new_x - drag_start_line_x
	delta_from_start = clamp(delta_from_start, -overscroll_limit, overscroll_limit)
	new_x = drag_start_line_x + delta_from_start
	
	line.position.x = new_x

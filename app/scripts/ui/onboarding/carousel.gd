extends Control

@export var ui_events: UiEvents
@export var line: Control
@export var tween_duration: float

var boards: Array[OnboardingBoard] = []
var focused_page: int
var tween: Tween


func _ready() -> void:
	setup_boards()
	assert(boards.size() > 0, "Carousel must have at least one board")
	
	move_line(0)


func setup_boards() -> void:
	for child in line.get_children():
		boards.append(child as OnboardingBoard)
	
	for i in range(boards.size()):
		boards[i].request_focus.connect(move_line.bind(i))


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

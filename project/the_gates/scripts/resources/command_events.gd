extends Resource
class_name CommandEvents

signal send_fd
signal set_mouse_mode(mode: int)


func send_fd_emit() -> void:
	send_fd.emit()


func set_mouse_mode_emit(mode: int) -> void:
	set_mouse_mode.emit(mode)

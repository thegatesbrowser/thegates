extends Resource
class_name CommandEvents

signal send_filehandle
signal set_mouse_mode(mode: int)


func send_filehandle_emit() -> void:
	send_filehandle.emit()


func set_mouse_mode_emit(mode: int) -> void:
	set_mouse_mode.emit(mode)

extends Resource
class_name CommandEvents

signal send_filehandle(filehandle_path: String)
signal set_mouse_mode(mode: int)


func send_filehandle_emit(filehandle_path: String) -> void:
	send_filehandle.emit(filehandle_path)


func set_mouse_mode_emit(mode: int) -> void:
	set_mouse_mode.emit(mode)

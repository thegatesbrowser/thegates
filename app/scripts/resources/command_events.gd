extends Resource
class_name CommandEvents

signal send_filehandle(filehandle_path: String)
signal ext_texture_format(format: RenderingDevice.DataFormat)
signal first_frame_drawn()
signal set_mouse_mode(mode: int)


func send_filehandle_emit(filehandle_path: String) -> void:
	send_filehandle.emit(filehandle_path)


func ext_texture_format_emit(format: RenderingDevice.DataFormat) -> void:
	ext_texture_format.emit(format)


func first_frame_drawn_emit() -> void:
	first_frame_drawn.emit()


func set_mouse_mode_emit(mode: int) -> void:
	set_mouse_mode.emit(mode)

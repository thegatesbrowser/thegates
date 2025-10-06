extends Resource
class_name CommandEvents

signal send_filehandle(filehandle_path: String)
signal ext_texture_format(format: RenderingDevice.DataFormat)
signal set_mouse_mode(mode: Input.MouseMode)
signal heartbeat()
signal highlight_button(button_id: String)


func send_filehandle_emit(filehandle_path: String) -> void:
	send_filehandle.emit(filehandle_path)


func ext_texture_format_emit(format: RenderingDevice.DataFormat) -> void:
	ext_texture_format.emit(format)


func set_mouse_mode_emit(mode: Input.MouseMode) -> void:
	set_mouse_mode.emit(mode)


func heartbeat_emit() -> void:
	heartbeat.emit()


func highlight_button_emit(button_id: String) -> void:
	highlight_button.emit(button_id)

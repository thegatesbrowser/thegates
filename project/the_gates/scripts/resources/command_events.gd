extends Resource
class_name CommandEvents

signal send_fd


func send_fd_emit() -> void:
	send_fd.emit()

extends Resource
class_name UiEvents

signal visibility_changed(visible: bool)


func visibility_changed_emit(visible: bool) -> void:
	visibility_changed.emit(visible)

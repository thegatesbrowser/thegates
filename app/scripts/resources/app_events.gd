extends Resource
class_name AppEvents

signal open_link(uri: String)


func open_link_emit(uri: String) -> void:
	OS.shell_open(uri) # TODO: move somewhere else
	open_link.emit(uri)

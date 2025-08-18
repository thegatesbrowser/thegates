extends Resource
class_name AppEvents

signal open_link(url: String)


func open_link_emit(url: String) -> void:
	OS.shell_open(url) # TODO: move somewhere else
	open_link.emit(url)

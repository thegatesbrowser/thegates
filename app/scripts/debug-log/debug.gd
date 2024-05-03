extends Node

signal logged(msg: String)
signal error(msg: String)

const ERROR_CLR = Color.RED
const WARN_CLR = Color.YELLOW
const SILENT_CLR = Color.DIM_GRAY


func logr(msg) -> void:
	print_rich(str(msg))
	logged.emit(str(msg))


func logerr(msg) -> void:
	printerr(str(msg))
	var rich_clr = "[color=%s]%s[/color]" % [Color.RED.to_html(), str(msg)]
	logged.emit(rich_clr)
	error.emit(msg)


func logclr(msg, color: Color) -> void:
	var rich_clr = "[color=%s]%s[/color]" % [color.to_html(), str(msg)]
	print_rich(rich_clr)
	logged.emit(rich_clr)

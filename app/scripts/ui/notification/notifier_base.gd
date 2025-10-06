extends Node
class_name NotifierBase

signal show(message: String, icon: Texture2D)
signal hide()

@export_multiline var message: String
@export var icon: Texture2D


func show_notification() -> void:
	show.emit(message, icon)


func hide_notification() -> void:
	hide.emit()

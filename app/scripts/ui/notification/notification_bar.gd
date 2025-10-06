extends Control
class_name NotificationBar

@export var notification_scene: PackedScene
@export var container: VBoxContainer


func show_notification(message: String, icon: Texture2D) -> NotificationPopup:
	var popup: NotificationPopup = notification_scene.instantiate()
	popup.fill(message, icon)
	
	container.add_child(popup)
	return popup


func hide_popup(popup: NotificationPopup) -> void:
	await popup.hide_notification() 
	popup.queue_free()

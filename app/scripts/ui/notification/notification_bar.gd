extends Control
class_name NotificationBar

@export var notification_scene: PackedScene
@export var container: VBoxContainer


func show_notification(message: String, icon: Texture2D) -> Notification:
	var ntf: Notification = notification_scene.instantiate()
	ntf.fill(message, icon)
	
	container.add_child(ntf)
	return ntf


func hide_notification(ntf: Notification) -> void:
	await ntf.hide_notification() 
	ntf.queue_free()

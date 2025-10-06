extends Node
class_name NotificationManager

@export var notification_bar: NotificationBar

var notifier_to_notification: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		register_notifier(child)


func register_notifier(node: Node) -> void:
	var notifier: NotifierBase = node
	notifier.show.connect(on_notification_show.bind(notifier))
	notifier.hide.connect(on_notification_hide.bind(notifier))


func on_notification_show(message: String, icon: Texture2D, notifier: NotifierBase) -> void:
	hide_for_notification(notifier)
	
	var ntf: Notification = notification_bar.show_notification(message, icon)
	notifier_to_notification[notifier] = ntf


func on_notification_hide(notifier: NotifierBase) -> void:
	hide_for_notification(notifier)


func hide_for_notification(notifier: NotifierBase) -> void:
	if not notifier_to_notification.has(notifier): return
	
	var ntf: Notification = notifier_to_notification[notifier]
	notification_bar.hide_notification(ntf)
	notifier_to_notification.erase(notifier)

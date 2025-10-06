extends Node
class_name NotificationManager

@export var notification_bar: NotificationBar

var notification_to_popup: Dictionary = {}


func _ready() -> void:
	for child in get_children():
		register_notification(child)


func register_notification(node: Node) -> void:
	var notif: NotificationBase = node
	notif.show.connect(on_notification_show.bind(notif))
	notif.hide.connect(on_notification_hide.bind(notif))


func on_notification_show(message: String, icon: Texture2D, notif: NotificationBase) -> void:
	hide_for_notification(notif)
	var popup: NotificationPopup = notification_bar.show_notification(message, icon)
	notification_to_popup[notif] = popup


func on_notification_hide(notif: NotificationBase) -> void:
	hide_for_notification(notif)


func hide_for_notification(notif: NotificationBase) -> void:
	if not notification_to_popup.has(notif): return
	var popup: NotificationPopup = notification_to_popup[notif]
	notification_to_popup.erase(notif)
	if notification_bar != null:
		notification_bar.hide_popup(popup)
	elif is_instance_valid(popup):
		popup.hide_notification()

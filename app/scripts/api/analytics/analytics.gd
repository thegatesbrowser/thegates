extends Node
class_name Analitycs

signal analytics_ready

@export var api: ApiSettings


func _ready() -> void:
	get_app_version()
	await get_user_id()
	analytics_ready.emit()


func get_app_version() -> void:
	AnalyticsEvents.app_version = ProjectSettings.get_setting("application/config/version")


func get_user_id() -> void:
	AnalyticsEvents.user_id = DataSaver.get_string("analytics", "user_id")
	if not AnalyticsEvents.user_id.is_empty(): return
	
	var url = api.create_user_id
	var callback = func(_result, code, _headers, body):
		if code == 200:
			AnalyticsEvents.user_id = body.get_string_from_utf8()
			DataSaver.set_value("analytics", "user_id", AnalyticsEvents.user_id)
			DataSaver.save_data()
		else: Debug.logclr("Request create_user_id failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request create_user_id", Color.RED)


func send_event(body: Dictionary = {}) -> void:
	var url = api.analytics_event
	var callback = func(_result, code, _headers, _body):
		if code != 200: Debug.logclr("Request send_event failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback, body, HTTPClient.METHOD_POST)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request send_event", Color.RED)

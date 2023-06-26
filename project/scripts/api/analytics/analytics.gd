extends Node
class_name Analitycs

@export var api: ApiSettings
signal analytics_ready


func _ready() -> void:
	await get_user_id()
	analytics_ready.emit()


func send_event(body: Dictionary = {}) -> void:
	var url = api.analytics_event
	var callback = func(_result, code, _headers, _body):
		if code != 200: Debug.logclr("Request send_event failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback, body, HTTPClient.METHOD_POST)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request send_event", Color.RED)


func get_user_id() -> void:
	var url = api.get_user_id + OS.get_unique_id()
	var callback = func(_result, code, _headers, body):
		if code == 200:
			AnalyticsEvents.user_id = body.get_string_from_utf8()
		else: Debug.logclr("Request get_user_id failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request get_user_id", Color.RED)

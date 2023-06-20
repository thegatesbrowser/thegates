extends Node
class_name Analitycs

@export var backend: BackendSettings
signal analytics_ready


func _ready() -> void:
	await get_user_id()
	analytics_ready.emit()


func send_event(body: Dictionary = {}) -> void:
	var url = backend.analytics_event
	var callback = func(_result, code, _headers, _body):
		if code != 200: Debug.logclr("Request send_event failed. Code " + str(code), Color.RED)
	
	var err = await request(url, callback, body, HTTPClient.METHOD_POST)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request send_event", Color.RED)


func get_user_id() -> void:
	var url = backend.get_user_id + OS.get_unique_id()
	var callback = func(_result, code, _headers, body):
		if code == 200:
			AnalyticsEvents.user_id = body.get_string_from_utf8()
		else: Debug.logclr("Request get_user_id failed. Code " + str(code), Color.RED)
	
	var err = await request(url, callback)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request get_user_id", Color.RED)


func request(url: String, callback: Callable,
		body: Dictionary = {}, method: int = HTTPClient.METHOD_GET) -> Error:
	var data = JSON.stringify(body)
	var headers = []
	
	var http = HTTPRequest.new()
	http.use_threads = true
	add_child(http)
	
	var err = http.request(url, headers, method, data)
	var res = await http.request_completed
	callback.call(res[0], res[1], res[2], res[3])
	remove_child(http)
	
	return err

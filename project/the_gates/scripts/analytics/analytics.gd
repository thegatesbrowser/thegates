extends Node
#class_name Analitycs

var backend := preload("res://the_gates/resources/backend.tres")
var user_id := "none"


func _ready() -> void:
	await get_user_id()
	send_event({
		"event_name" : "application_enter",
		"user_id" : user_id
	})


func send_event(body: Variant = []) -> void:
	var url = backend.analytics_event
	var callback = func(result, code, headers, body):
		if code != 200: Debug.logerr("Request send_event failed. Code " + str(code))
	
	var err = await request(url, callback, body, HTTPClient.METHOD_POST)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logerr("Cannot send request send_event")


func get_user_id() -> void:
	var url = backend.get_user_id + OS.get_unique_id()
	var callback = func(result, code, headers, body):
		if code == 200:
			user_id = body.get_string_from_utf8()
			Debug.logr("User id recieved: " + user_id)
		else: Debug.logerr("Request get_user_id failed. Code " + str(code))
	
	var err = await request(url, callback)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logerr("Cannot send request get_user_id")


func request(url: String, callback: Callable,
		body: Variant = [], method: int = HTTPClient.METHOD_GET) -> Error:
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

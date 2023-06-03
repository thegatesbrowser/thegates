extends Node
#class_name Analitycs

var backend_settings = preload("res://the_gates/resources/backend_settings.tres")
var handle = "api/analytics"

func _ready() -> void:
	send_event("application_enter")


func send_event(name: String, body: Variant = null) -> void:
	var url = backend_settings.url + handle
	var data = JSON.stringify(body)
	
	var http = HTTPRequest.new()
	http.use_threads = true
	add_child(http)
	
	var err = http.request(url, [], HTTPClient.METHOD_POST, data)
	await http.request_completed
	remove_child(http)
	
	if err != HTTPRequest.RESULT_SUCCESS:
		Debug.logerr("Analitycs event is not sent. Name: " + name)

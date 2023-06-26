extends Node
#class_name Backend


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

extends Node
#class_name Backend


func request(url: String, callback: Callable,
		body: Dictionary = {}, method: int = HTTPClient.METHOD_GET,
		cancel_callbacks: Array = []) -> Error:
	
	var data = JSON.stringify(body)
	var headers = []
	
	var http = HttpClientRequest.new()
	http.use_threads = true
	
	var err = http.request(url, headers, method, data)
	cancel_callbacks.append(http.cancel_request)
	var res = await http.request_completed
	
	# If calling object is freed without canceling request
	if not callback.is_valid(): return ERR_INVALID_PARAMETER
	
	callback.call(res[0], res[1], res[2], res[3])
	
	return err


func request_raw(url: String, callback: Callable,
		data: PackedByteArray, method: int = HTTPClient.METHOD_GET,
		cancel_callbacks: Array = []) -> Error:
	
	var headers = []
	
	var http = HttpClientRequest.new()
	http.use_threads = true
	
	var err = http.request_raw(url, headers, method, data)
	cancel_callbacks.append(http.cancel_request)
	var res = await http.request_completed
	
	# If calling object is freed without canceling request
	if not callback.is_valid(): return ERR_INVALID_PARAMETER
	
	callback.call(res[0], res[1], res[2], res[3])
	
	return err

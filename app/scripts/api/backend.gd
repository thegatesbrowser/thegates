extends Node
#class_name Backend


func request(url: String, callback: Callable,
		body: Dictionary = {}, method: int = HTTPClient.METHOD_GET,
		cancel_callback: Array = []) -> Error:
	
	var data = JSON.stringify(body)
	var headers = []
	var http = HttpClientRequest.new()
	
	var err = http.request(url, headers, method, data)
	cancel_callback.append(http.cancel_request)
	var res = await http.request_completed
	
	# If calling object is freed without canceling request
	if not callback.is_valid(): return ERR_INVALID_PARAMETER
	
	callback.call(res[0], res[1], res[2], res[3])
	
	return err


func request_raw(url: String, callback: Callable,
		data: PackedByteArray, method: int = HTTPClient.METHOD_GET,
		cancel_callback: Array = []) -> Error:
	
	var headers = []
	var http = HttpClientRequest.new()
	
	var err = http.request_raw(url, headers, method, data)
	cancel_callback.append(http.cancel_request)
	var res = await http.request_completed
	
	# If calling object is freed without canceling request
	if not callback.is_valid(): return ERR_INVALID_PARAMETER
	
	callback.call(res[0], res[1], res[2], res[3])
	
	return err

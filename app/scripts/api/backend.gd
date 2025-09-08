extends Node
#class_name Backend

var cancel_http_func: Callable = func(http: HTTPRequestPooled):
	if is_instance_valid(http):
		http.cancel_request()
		http.queue_free()


func request(url: String, callback: Callable,
		body: Dictionary = {}, method: int = HTTPClient.METHOD_GET,
		cancel_callbacks: Array[Callable] = []) -> Error:
	
	var data = JSON.stringify(body)
	var headers = []
	
	var http = HTTPRequestPooled.new()
	http.use_threads = true
	add_child(http)
	
	var canceler: Callable = cancel_http_func.bind(http)
	cancel_callbacks.append(canceler)
	
	var start_ms = Time.get_ticks_msec()
	var err = http.request(url, headers, method, data)
	var res = await http.request_completed
	Debug.logclr("API request " + url + " code=" + str(res[1]) + " duration_ms=" + str(Time.get_ticks_msec() - start_ms), Color.DIM_GRAY)
	
	# If calling object is freed without canceling request
	if not callback.is_valid(): return ERR_INVALID_PARAMETER
	
	callback.call(res[0], res[1], res[2], res[3])
	cancel_callbacks.erase(canceler)
	http.queue_free()
	
	return err


func request_raw(url: String, callback: Callable,
		data: PackedByteArray, method: int = HTTPClient.METHOD_GET,
		cancel_callbacks: Array[Callable] = []) -> Error:
	
	var headers = []
	
	var http = HTTPRequestPooled.new()
	http.use_threads = true
	add_child(http)
	
	var canceler: Callable = cancel_http_func.bind(http)
	cancel_callbacks.append(canceler)
	
	var start_ms = Time.get_ticks_msec()
	var err = http.request_raw(url, headers, method, data)
	var res = await http.request_completed
	Debug.logclr("API request " + url + " code=" + str(res[1]) + " duration_ms=" + str(Time.get_ticks_msec() - start_ms), Color.DIM_GRAY)
	
	# If calling object is freed without canceling request
	if not callback.is_valid(): return ERR_INVALID_PARAMETER
	
	callback.call(res[0], res[1], res[2], res[3])
	cancel_callbacks.erase(canceler)
	http.queue_free()
	
	return err

extends HTTPRequest
class_name HTTPRequestPooled

var http_client: HTTPClient
var request_started_ms: int


func _ready() -> void:
	request_cancelled.connect(on_request_done)


func _get_http_client(host: String, port: int, use_tls: bool) -> HTTPClient:
	request_started_ms = Time.get_ticks_msec()
	http_client = HTTPClientPool.acquire_client(self, host, port, use_tls)
	return http_client


func on_request_done() -> void:
	if http_client == null: return
	HTTPClientPool.release_client(http_client)
	http_client = null
	
	print("[HTTPRequestPooled] duration_ms=", Time.get_ticks_msec() - request_started_ms)

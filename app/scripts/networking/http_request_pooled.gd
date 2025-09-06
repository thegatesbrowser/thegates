extends HTTPRequest
class_name HTTPRequestPooled


func _get_http_client(host: String, port: int, use_tls: bool) -> HTTPClient:
	return HTTPClientPool.acquire_client(self, host, port, use_tls)

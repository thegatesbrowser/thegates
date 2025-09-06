extends HTTPRequest
class_name HTTPRequestPooled


func _get_http_client() -> HTTPClient:
	return HTTPClient.new()

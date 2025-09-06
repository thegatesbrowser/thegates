extends Node
# class_name HTTPClientPool

var client: HTTPClient


func _ready() -> void:
	client = HTTPClient.new()


func acquire_client(_http: HTTPRequestPooled, host: String, port: int, use_tls: bool) -> HTTPClient:
	if client.get_status() == HTTPClient.STATUS_DISCONNECTED:
		client.connect_to_host(host, port, TLSOptions.client() if use_tls else null)
	
	return client

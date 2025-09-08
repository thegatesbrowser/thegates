extends Node
#class_name HTTPClientPool

@export var keepalive_poll_interval_sec: float = 0.3
@export var drain_timeout_ms: int = 2000

const LOG_TAG: String = "[HTTPClientPool]"

var client_to_key: Dictionary = {}
var available_by_key: Dictionary = {}
var mutex: Mutex = Mutex.new()

var poll_accumulator_sec: float
var keepalive_log_counter: int


func _process(delta: float) -> void:
	poll_accumulator_sec += delta
	if poll_accumulator_sec < keepalive_poll_interval_sec: return
	poll_accumulator_sec = 0.0
	
	# Poll only idle (available) clients to keep connections alive
	mutex.lock()
	var snapshot: Array = []
	for key in available_by_key.keys():
		var list: Array = available_by_key[key]
		for c in list:
			snapshot.append(c)
	mutex.unlock()
	
	keepalive_log_counter += 1
	if keepalive_log_counter % 16 == 0:
		print("%s keepalive poll; idle_clients=%d" % [LOG_TAG, snapshot.size()])
	
	for client in snapshot:
		if client is HTTPClient:
			var status: int = client.get_status()
			if status in [HTTPClient.STATUS_CONNECTED, HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING]:
				client.poll()
			else:
				mutex.lock()
				for key in available_by_key.keys():
					var list: Array = available_by_key[key]
					list.erase(client)
					available_by_key[key] = list
				mutex.unlock()
				print("%s keepalive poll; removed client; status=%d" % [LOG_TAG, status])


func acquire_client(_http: HTTPRequestPooled, host: String, port: int, use_tls: bool) -> HTTPClient:
	var key: String = make_key(host, port, use_tls)
	var client: HTTPClient = get_fresh_client_for_key(key)
	
	print("%s acquire requested key=%s (host=%s port=%d tls=%s); had_available=%s size_after_pop=%d" % [
		LOG_TAG, key, host, port, str(use_tls), str(client != null), (available_by_key.get(key, []) as Array).size()
	])
	
	if client == null:
		client = HTTPClient.new()
		print("%s created new HTTPClient for key=%s" % [LOG_TAG, key])
	
	if client.get_status() in [HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CANT_RESOLVE, \
			HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR, \
			HTTPClient.STATUS_BODY, HTTPClient.STATUS_REQUESTING]:
		print("%s connecting to host=%s port=%d tls=%s" % [LOG_TAG, host, port, str(use_tls)])
		client.connect_to_host(host, port, TLSOptions.client() if use_tls else null)
	
	mutex.lock()
	client_to_key[client] = key
	mutex.unlock()
	
	print("%s acquired client for key=%s; status=%d" % [LOG_TAG, key, client.get_status()])
	return client


func release_client(client: HTTPClient) -> void:
	if client == null: return
	mutex.lock()
	var key: String = client_to_key.get(client, "")
	mutex.unlock()
	if key == "": return
	
	var start_time: int = Time.get_ticks_msec()
	while true:
		var status: int = client.get_status()
		
		match status:
			HTTPClient.STATUS_CONNECTED:
				break
				
			HTTPClient.STATUS_BODY:
				print("%s release: draining leftover body; status=%d" % [LOG_TAG, status])
				var drained_ok: bool = await drain_body(client, drain_timeout_ms)
				status = client.get_status()
				print("%s release: drain result=%s status_now=%d" % [LOG_TAG, str(drained_ok), status])
				continue
				
			HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CANT_CONNECT, \
			HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
				mutex.lock()
				client_to_key.erase(client)
				mutex.unlock()
				print("%s release dropped during await; status=%d" % [LOG_TAG, status])
				return
				
			_:
				client.poll()
		
		if Time.get_ticks_msec() - start_time > drain_timeout_ms:
			mutex.lock()
			client_to_key.erase(client)
			mutex.unlock()
			print("%s release timeout awaiting idle; dropped; last_status=%d" % [LOG_TAG, status])
			return
		
		await get_tree().process_frame
	
	mutex.lock()
	var list: Array = available_by_key.get(key, [])
	list.append(client)
	available_by_key[key] = list
	client_to_key.erase(client)
	mutex.unlock()
	
	print("%s released client back to pool; key=%s pool_size=%d" % [LOG_TAG, key, (available_by_key.get(key, []) as Array).size()])


func drain_body(client: HTTPClient, timeout_ms: int) -> bool:
	var start_time: int = Time.get_ticks_msec()
	var iterations: int = 0
	
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk: PackedByteArray = client.read_response_body_chunk()
		
		iterations += 1
		if iterations % 32 == 0:
			print("%s draining body... iter=%d chunk_size=%d" % [LOG_TAG, iterations, chunk.size()])
		
		if Time.get_ticks_msec() - start_time > timeout_ms:
			return false
		
		await get_tree().process_frame
	
	return client.get_status() == HTTPClient.STATUS_CONNECTED


func get_connection_count(endpoint: HTTPEndpoint) -> int:
	var key: String = make_key(endpoint.host, endpoint.port, endpoint.use_tls)
	var available_count: int = (available_by_key.get(key, []) as Array).size()
	var in_use_count: int = 0
	
	mutex.lock()
	for c in client_to_key.keys():
		if String(client_to_key[c]) == key:
			in_use_count += 1
	mutex.unlock()
	
	return available_count + in_use_count


func spawn_idle_connection(endpoint: HTTPEndpoint) -> void:
	var key: String = make_key(endpoint.host, endpoint.port, endpoint.use_tls)
	print("%s spawn requested key=%s (host=%s port=%d tls=%s)" % [LOG_TAG, key, endpoint.host, endpoint.port, str(endpoint.use_tls)])
	
	var client: HTTPClient = HTTPClient.new()
	client.connect_to_host(endpoint.host, endpoint.port, TLSOptions.client() if endpoint.use_tls else null)
	
	mutex.lock()
	var list: Array = available_by_key.get(key, [])
	list.append(client)
	available_by_key[key] = list
	mutex.unlock()


func make_key(host: String, port: int, use_tls: bool) -> String:
	return "%s:%d:%s" % [host, port, ("tls" if use_tls else "plain")]


func get_fresh_client_for_key(key: String) -> HTTPClient:
	# Select the most ready client for the given key. Prefer CONNECTED, then CONNECTING/RESOLVING, then others.
	mutex.lock()
	var list: Array = available_by_key.get(key, [])
	if list.is_empty():
		mutex.unlock()
		return null
	
	# Build pairs of (score, client) and then pick the best.
	var best_idx: int = -1
	var best_score: int = -99999
	for i in range(list.size()):
		var c: HTTPClient = list[i]
		var status: int = c.get_status()
		var score: int = 0
		match status:
			HTTPClient.STATUS_CONNECTED:
				score = 100
			HTTPClient.STATUS_CONNECTING:
				score = 50
			HTTPClient.STATUS_RESOLVING:
				score = 25
			HTTPClient.STATUS_DISCONNECTED, HTTPClient.STATUS_CANT_RESOLVE, HTTPClient.STATUS_CANT_CONNECT, HTTPClient.STATUS_CONNECTION_ERROR, HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
				score = -10
			HTTPClient.STATUS_BODY, HTTPClient.STATUS_REQUESTING:
				score = -100
			_:
				score = -50
		if score > best_score:
			best_score = score
			best_idx = i
	
	var client: HTTPClient = null
	if best_idx != -1:
		client = list[best_idx]
		list.remove_at(best_idx)
		available_by_key[key] = list
	mutex.unlock()
	
	return client

# TODO: cleanup ai generated code

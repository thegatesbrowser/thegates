extends Node
#class_name HTTPClientPool

const DEFAULT_CONNECT_TIMEOUT_MS: int = 5000
const KEEPALIVE_POLL_INTERVAL_SEC: float = 3.0
const LOG_TAG: String = "[HTTPClientPool]"
const DRAIN_TIMEOUT_MS: int = 2000

var mutex: Mutex
var available_by_key: Dictionary = {}
var client_to_key: Dictionary = {}
var poll_accumulator_sec: float = 0.0


func _ready() -> void:
	mutex = Mutex.new()
	set_process(true)
	print("%s initialized" % LOG_TAG)


func _process(delta: float) -> void:
	poll_accumulator_sec += delta
	if poll_accumulator_sec < KEEPALIVE_POLL_INTERVAL_SEC:
		return
	poll_accumulator_sec = 0.0

	# Poll only idle (available) clients to keep connections alive
	mutex.lock()
	var snapshot: Array = []
	for key in available_by_key.keys():
		var list: Array = available_by_key[key]
		for c in list:
			snapshot.append(c)
	mutex.unlock()

	print("%s keepalive poll; idle_clients=%d" % [LOG_TAG, snapshot.size()])
	for client in snapshot:
		if client is HTTPClient:
			var status: int = client.get_status()
			if status == HTTPClient.STATUS_CONNECTED or status == HTTPClient.STATUS_CONNECTING or status == HTTPClient.STATUS_RESOLVING:
				client.poll()


func acquire_client(_http: HTTPRequestPooled, host: String, port: int, use_tls: bool) -> HTTPClient:
	var key: String = make_key(host, port, use_tls)
	var client: HTTPClient = null

	mutex.lock()
	var list: Array = available_by_key.get(key, [])
	if list.size() > 0:
		client = list.pop_back()
		available_by_key[key] = list
	mutex.unlock()

	print("%s acquire requested key=%s (host=%s port=%d tls=%s); had_available=%s size_after_pop=%d" % [
		LOG_TAG, key, host, port, str(use_tls), str(client != null), (available_by_key.get(key, []) as Array).size()
	])

	if client == null:
		client = HTTPClient.new()
		print("%s created new HTTPClient for key=%s" % [LOG_TAG, key])

	if client.get_status() == HTTPClient.STATUS_DISCONNECTED:
		print("%s connecting to host=%s port=%d tls=%s timeout_ms=%d" % [LOG_TAG, host, port, str(use_tls), DRAIN_TIMEOUT_MS])
		client.connect_to_host(host, port, TLSOptions.client() if use_tls else null)

	mutex.lock()
	client_to_key[client] = key
	mutex.unlock()

	print("%s acquired client for key=%s; status=%d" % [LOG_TAG, key, client.get_status()])
	return client


func release_client(client: HTTPClient) -> void:
	if client == null:
		print("%s release called with null client; ignoring" % LOG_TAG)
		return

	var status: int = client.get_status()
	if status == HTTPClient.STATUS_BODY:
		print("%s release: draining leftover body; status=%d" % [LOG_TAG, status])
		var drained_ok: bool = await drain_body(client, DRAIN_TIMEOUT_MS)
		status = client.get_status()
		print("%s release: drain result=%s status_now=%d" % [LOG_TAG, str(drained_ok), status])

	if status == HTTPClient.STATUS_DISCONNECTED or status == HTTPClient.STATUS_CONNECTION_ERROR or status == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR or status == HTTPClient.STATUS_REQUESTING:
		# Drop broken client
		mutex.lock()
		client_to_key.erase(client)
		mutex.unlock()
		print("%s release dropped broken client; status=%d" % [LOG_TAG, status])
		return

	if status != HTTPClient.STATUS_CONNECTED:
		# Not safe to reuse; drop it
		mutex.lock()
		client_to_key.erase(client)
		mutex.unlock()
		print("%s release dropped non-idle client; status=%d" % [LOG_TAG, status])
		return

	mutex.lock()
	var key: String = client_to_key.get(client, "")
	if key == "":
		# Unknown client; drop it
		mutex.unlock()
		print("%s release unknown client; dropping" % LOG_TAG)
		return

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


func make_key(host: String, port: int, use_tls: bool) -> String:
	return "%s:%d:%s" % [host, port, ("tls" if use_tls else "plain")]

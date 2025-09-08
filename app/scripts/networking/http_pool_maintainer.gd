extends Node
class_name HTTPPoolMaintainer

@export var endpoints: Array[HTTPEndpoint]
@export var check_interval_sec: float = 0.3

var accumulator_sec: float


func _enter_tree() -> void:
	maintain_connections()


func _process(delta: float) -> void:
	accumulator_sec += delta
	if accumulator_sec < check_interval_sec: return
	accumulator_sec = 0.0
	
	maintain_connections()


func maintain_connections() -> void:
	for endpoint in endpoints:
		var current = HTTPClientPool.get_connection_count(endpoint)
		var need = endpoint.desired_connections - current
		if need <= 0: continue
		
		for i in range(need):
			HTTPClientPool.spawn_idle_connection(endpoint)

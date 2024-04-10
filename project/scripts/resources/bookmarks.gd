extends Resource
class_name Bookmarks

signal on_ready()
signal on_star(gate: Gate)
signal on_unstar(gate: Gate)
signal save_image(gate: Gate)

@export var starred_gates: Array[Gate]

var is_ready: bool
var gates = {}


func ready() -> void:
	for gate in starred_gates:
		if gate == null or not Url.is_valid(gate.url): continue
		gates[gate.url] = gate
	
	is_ready = true
	on_ready.emit()


func update(gate: Gate) -> void:
	if not gates.has(gate.url): return
	
	var replace = gates[gate.url]
	
	gates[gate.url] = gate
	starred_gates.erase(replace)
	starred_gates.append(gate)
	
	save_image.emit(gate)


func star(gate: Gate) -> void:
	if gates.has(gate.url): return
	
	gates[gate.url] = gate
	starred_gates.append(gate)
	
	save_image.emit(gate)
	on_star.emit(gate)


func unstar(gate: Gate) -> void:
	if not gates.has(gate.url): return
	
	var erase: Gate = gates[gate.url]
	gates.erase(erase.url)
	starred_gates.erase(erase)
	
	on_unstar.emit(gate)

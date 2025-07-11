extends Resource
class_name Bookmarks

signal on_ready()
signal on_star(gate: Gate, featured: bool)
signal on_unstar(gate: Gate)
signal on_update(gate: Gate)
signal save_icon(gate: Gate)

@export var starred_gates: Array[Gate]

var is_ready: bool
var gates = {}


func ready() -> void:
	for gate in starred_gates.duplicate():
		if not is_instance_valid(gate) or not Url.is_valid(gate.url) or gates.has(gate.url):
			starred_gates.erase(gate); continue # Remove invalid and duplicates
		gates[gate.url] = gate
	
	is_ready = true
	on_ready.emit()


func update(gate: Gate) -> void:
	if not gates.has(gate.url): return
	
	var replace = gates[gate.url]
	
	gates.erase(gate.url)
	gates[gate.url] = gate
	
	starred_gates.erase(replace)
	starred_gates.append(gate)
	
	save_icon.emit(gate)
	on_update.emit(gate)


func star(gate: Gate, featured: bool = false) -> void:
	if gates.has(gate.url): return
	
	gates[gate.url] = gate
	starred_gates.append(gate)
	
	save_icon.emit(gate)
	on_star.emit(gate, featured)


func unstar(gate: Gate) -> void:
	if not gates.has(gate.url): return
	
	var erase: Gate = gates[gate.url]
	gates.erase(erase.url)
	starred_gates.erase(erase)
	
	on_unstar.emit(gate)

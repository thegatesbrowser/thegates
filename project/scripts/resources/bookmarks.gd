extends Resource
class_name Bookmarks

signal save_image(gate: Gate)

@export var featured_gates: Array[Gate]
@export var starred_gates: Array[Gate]
var gates = {}


func ready() -> void:
	var add_to_dict = func(array: Array[Gate]):
		for gate in array:
			if gate == null or not Url.is_valid(gate.url): continue
			gates[gate.url] = gate
	
	add_to_dict.call(featured_gates)
	add_to_dict.call(starred_gates)


func is_featured(url: String) -> bool:
	for gate in featured_gates:
		if gate.url == url:
			return true
	return false


func update(gate: Gate) -> void:
	if not gates.has(gate.url): return
	
	var replace = gates[gate.url]
	
	gates[gate.url] = gate
	if is_featured(gate.url):
		featured_gates.erase(replace)
		featured_gates.append(gate)
	else:
		starred_gates.erase(replace)
		starred_gates.append(gate)
	save_image.emit(gate)


func star(gate: Gate) -> void:
	if gates.has(gate.url): return
	
	gates[gate.url] = gate
	starred_gates.append(gate)
	save_image.emit(gate)


func unstar(gate: Gate) -> void:
	if not gates.has(gate.url): return
	
	var erase: Gate = gates[gate.url]
	gates.erase(erase.url)
	starred_gates.erase(erase)

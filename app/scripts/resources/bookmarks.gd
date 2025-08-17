extends Resource
class_name Bookmarks

signal on_ready()
signal on_star(gate: Gate)
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


func make_first(url: String) -> void:
	if not gates.has(url): return
	
	var gate = gates[url]
	gates.erase(url)
	gates[url] = gate


func update_icon(url: String, icon: String) -> void:
	if not gates.has(url): return
	
	var gate = gates[url]
	gate.icon = icon
	
	var index = starred_gates.find(gate)
	starred_gates[index].icon = icon
	
	save_icon.emit(gate)


func update(gate: Gate) -> void:
	if not gates.has(gate.url): return
	
	var replace = gates[gate.url]
	
	if gate.icon_url == replace.icon_url: gate.icon = replace.icon
	if gate.image_url == replace.image_url: gate.image = replace.image
	
	gates.erase(gate.url)
	gates[gate.url] = gate
	
	starred_gates.erase(replace)
	starred_gates.append(gate)
	
	save_icon.emit(gate)
	on_update.emit(gate)


func star(gate: Gate) -> void:
	if gates.has(gate.url): return
	
	gates[gate.url] = gate
	starred_gates.append(gate)
	
	save_icon.emit(gate)
	on_star.emit(gate)


func unstar(gate: Gate) -> void:
	if not gates.has(gate.url): return
	
	var erase: Gate = gates[gate.url]
	gates.erase(erase.url)
	starred_gates.erase(erase)
	
	on_unstar.emit(gate)

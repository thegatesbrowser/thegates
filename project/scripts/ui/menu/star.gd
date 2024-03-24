extends Node

@export var gate_events: GateEvents
@export var bookmarks: Bookmarks

@export var star: Control
@export var unstar: Control

var gate: Gate
var url: String


func _ready() -> void:
	star.visible = false
	unstar.visible = false
	
	gate_events.open_gate.connect(show_buttons)
	gate_events.search.connect(func(_query): hide_buttons())
	gate_events.exit_gate.connect(hide_buttons)
	gate_events.gate_info_loaded.connect(update_info)


func show_buttons(_url: String) -> void:
	url = _url
	if bookmarks.is_featured(url):
		star.visible = false
		unstar.visible = false
	elif bookmarks.gates.has(url):
		star.visible = false
		unstar.visible = true
	else:
		star.visible = true
		unstar.visible = false


func hide_buttons() -> void:
	star.visible = false
	unstar.visible = false


func update_info(_gate: Gate, _is_cached: bool) -> void:
	gate = _gate
	if bookmarks.gates.has(gate.url):
		bookmarks.update(gate)



func _on_star_pressed() -> void:
	if gate == null:
		gate = Gate.new()
		gate.url = url
	
	bookmarks.star(gate)
	star.visible = false
	unstar.visible = true


func _on_unstar_pressed() -> void:
	if gate == null:
		gate = Gate.new()
		gate.url = url
	
	bookmarks.unstar(gate)
	star.visible = true
	unstar.visible = false

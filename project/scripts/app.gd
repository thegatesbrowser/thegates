extends Node

@export var gate_events: GateEvents
@export var bookmarks: PackedScene
@export var world_scene: PackedScene
@export var scenes_root: Node


func _ready() -> void:
	gate_events.open_gate.connect(func(_url): switch_scene(world_scene))
	gate_events.exit_gate.connect(func(): switch_scene(bookmarks))
	
	scenes_root.add_child(bookmarks.instantiate())


func switch_scene(scene: PackedScene) -> void:
	for child in scenes_root.get_children(): child.queue_free()
	await get_tree().process_frame
	
	scenes_root.add_child(scene.instantiate())

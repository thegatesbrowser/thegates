extends Node

# TODO: restore `class_name Autotest` reference once the editor regenerates
# the global script class cache (open project.godot in the editor once).
# Kept as preload() for agent-loop iteration: avoids requiring an editor run
# every time autotest.gd is added/renamed.
const Autotest := preload("res://scripts/autotest.gd")

@export var gate_events: GateEvents
@export var home: PackedScene
@export var search_results: PackedScene
@export var world_scene: PackedScene
@export var scenes_root: Node


func _ready() -> void:
	gate_events.search.connect(func(_query): switch_scene(search_results))
	gate_events.open_gate_app.connect(func(_url): switch_scene(world_scene))
	gate_events.exit_gate.connect(func(): switch_scene(home))

	switch_scene(home)

	if Autotest.is_enabled():
		Autotest.start(self, gate_events)


func switch_scene(scene: PackedScene) -> void:
	for child in scenes_root.get_children(): child.queue_free()
	scenes_root.add_child(scene.instantiate())

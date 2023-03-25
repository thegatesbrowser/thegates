extends Node

@export var gate_events: GateEvents
@export var menu_scene: PackedScene
@export var world_scene: PackedScene


func _ready() -> void:
	gate_events.open_gate.connect(switch_scene.bind(world_scene))
	gate_events.exit_gate.connect(switch_scene.bind(menu_scene))
	
	$Scenes.add_child(menu_scene.instantiate())


func switch_scene(scene: PackedScene) -> void:
	for child in $Scenes.get_children(): child.queue_free()
	await get_tree().process_frame
	
	$Scenes.add_child(scene.instantiate())

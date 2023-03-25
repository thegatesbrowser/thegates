extends Node
class_name PackLoader

@export var gate_events: GateEvents
@export var scenes_parent: Node

var gate: Gate
var p_config: PackConfig


func _ready() -> void:
	gate_events.gate_loaded.connect(load_pack)


func load_pack(_gate: Gate) -> void:
	gate = _gate
	var success = ProjectSettings.load_resource_pack(gate.resource_pack)
	if not success: Debug.logerr("cannot load pck"); return
	
	p_config = PackConfig.new(gate.godot_config)
	p_config.load_config()
	
	var scene = load(p_config.scene_path)
	scenes_parent.add_child(scene.instantiate())
	
	gate_events.gate_entered_emit()


func unload_pack() -> void:
	if gate == null: return
	var success = ProjectSettings.unload_resource_pack(gate.resource_pack)
	if not success: Debug.logerr("cannot unload pck")
	else: Debug.logr("\nunloaded " + gate.resource_pack + "\n")
	
	if p_config != null: p_config.unload_config()


func _exit_tree() -> void:
	unload_pack()

extends Node
class_name PackLoader

@export var gate_events: GateEvents
@export var scenes_parent: Node

var gate: Gate
var c_g_script: ConfigGlobalScript
var c_godot: ConfigGodot


func _ready() -> void:
	gate_events.gate_loaded.connect(load_pack)


func load_pack(_gate: Gate) -> void:
	gate = _gate
	var success = ProjectSettings.load_resource_pack(gate.resource_pack)
	if not success: Debug.logerr("cannot load pck"); return
	
	c_g_script = ConfigGlobalScript.new(gate.global_script_class)
	c_godot = ConfigGodot.new(gate.godot_config)
	
	c_g_script.load_config() # Loading order is important
	c_godot.load_config()
	
	var scene = load(c_godot.scene_path)
	scenes_parent.add_child(scene.instantiate())
	
	gate_events.gate_entered_emit()


func unload_pack() -> void:
	if gate == null: return
	var success = ProjectSettings.unload_resource_pack(gate.resource_pack)
	if not success: Debug.logerr("cannot unload pck")
	else: Debug.logr("\nunloaded " + gate.resource_pack + "\n")
	
	if c_godot != null: c_godot.unload_config()
	if c_g_script != null: c_g_script.unload_config()


func _exit_tree() -> void:
	unload_pack()

extends Node
class_name PackLoader

@export var gate_events: GateEvents
@export var scenes_parent: Node

var gate: Gate
var c_g_script: ConfigGlobalScript
var c_godot: ConfigGodot

var pid: int


func _ready() -> void:
#	gate_events.gate_loaded.connect(load_pack)
	gate_events.gate_loaded.connect(create_process)


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


func create_process(_gate: Gate) -> void:
	gate = _gate
	
	var rd = RenderingServer.get_rendering_device() as RenderingDevice
	var width = get_viewport().size.x
	var height = get_viewport().size.y
	var fd = rd.create_external_texture(width, height)
	
	var main_pid = OS.get_process_id()
	
	var pack_file = ProjectSettings.globalize_path(gate.resource_pack)
	var sandbox_path = "/home/nordup/projects/godot/the-gates-folder/the-gates/bin/godot.linuxbsd.editor.dev.sandbox.x86_64.llvm"
	var args = [
		"--main-pack", pack_file,
		"--resolution", "%dx%d" % [width, height],
		"--external-image", fd,
		"--main-pid", main_pid
	]
	print(sandbox_path + " " + " ".join(args))
	pid = OS.create_process(sandbox_path, args)


func kill_process() -> void:
	if OS.is_process_running(pid):
		OS.kill(pid)


func _exit_tree() -> void:
#	unload_pack()
	kill_process()

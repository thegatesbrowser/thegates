extends Node
class_name PackLoader

@export var gate_events: GateEvents
@export var render_result: RenderResult

var gate: Gate
var pid: int


func _ready() -> void:
	gate_events.gate_loaded.connect(create_process)


func create_process(_gate: Gate) -> void:
	gate = _gate
	
	var sandbox_path = "/home/nordup/projects/godot/the-gates-folder/the-gates/bin/godot.linuxbsd.editor.dev.sandbox.x86_64.llvm"
	var pack_file = ProjectSettings.globalize_path(gate.resource_pack)
	var main_pid = OS.get_process_id()
	
	var args = [
		"--main-pack", pack_file,
		"--resolution", "%dx%d" % [render_result.width, render_result.height],
		"--fd-path", render_result.fd_path
	]
	Debug.logclr(sandbox_path + " " + " ".join(args), Color.DARK_VIOLET)
	pid = OS.create_process(sandbox_path, args)
	
	gate_events.gate_entered_emit()


func kill_process() -> void:
	if OS.is_process_running(pid):
		OS.kill(pid)
		Debug.logclr("Process killed " + str(pid), Color.DIM_GRAY)


func _exit_tree() -> void:
	kill_process()

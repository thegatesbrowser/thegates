extends Node
class_name SandboxManager

@export var gate_events: GateEvents
@export var render_result: RenderResult
@export var snbx_executable: SandboxExecutable

var sandbox_pid: int


func _ready() -> void:
	gate_events.gate_loaded.connect(create_process)


func create_process(gate: Gate) -> void:
	if not snbx_executable.exists():
		Debug.logerr("Sandbox executable not found at " + snbx_executable.path); return
	
	var pack_file = ProjectSettings.globalize_path(gate.resource_pack)
	var args = [
		"--main-pack", pack_file,
		"--resolution", "%dx%d" % [render_result.width, render_result.height]
	]
	Debug.logclr(snbx_executable.path + " " + " ".join(args), Color.DARK_VIOLET)
	sandbox_pid = OS.create_process(snbx_executable.path, args)
	
	gate_events.gate_entered_emit()


func kill_process() -> void:
	if OS.is_process_running(sandbox_pid):
		OS.kill(sandbox_pid)
		Debug.logclr("Process killed " + str(sandbox_pid), Color.DIM_GRAY)


func _exit_tree() -> void:
	kill_process()

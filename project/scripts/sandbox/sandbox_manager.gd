extends Node
class_name SandboxManager

@export var gate_events: GateEvents
@export var render_result: RenderResult
@export var snbx_executable: SandboxExecutable
@export var snbx_env: SandboxEnv

var sandbox_pid: int


func _ready() -> void:
	gate_events.gate_loaded.connect(start_sandbox)


func start_sandbox(gate: Gate) -> void:
	if not snbx_executable.exists():
		Debug.logerr("Sandbox executable not found at " + snbx_executable.path); return
	if not snbx_env.zip_exists():
		Debug.logerr("Sandbox environment not found at " + snbx_env.zip_path); return
	
	snbx_env.create_env(snbx_executable.path, gate)
	
#	var pack_file = ProjectSettings.globalize_path(gate.resource_pack)
#	var shared_libs = ProjectSettings.globalize_path(gate.shared_libs_dir)
	var args = [
		snbx_env.start.get_base_dir(), # cd to dir
		"--main-pack", snbx_env.main_pack,
#		"--gdext-libs-dir", shared_libs,
		"--resolution", "%dx%d" % [render_result.width, render_result.height]
	]
	Debug.logclr(snbx_env.start + " " + " ".join(args), Color.DARK_VIOLET)
	sandbox_pid = OS.create_process(snbx_env.start, args)
	
	gate_events.gate_entered_emit()


func kill_sandbox() -> void:
	if sandbox_pid == 0: return
	
	var pids = snbx_env.get_subprocesses(sandbox_pid)
	pids.append(sandbox_pid)
	
	for pid in pids:
		OS.kill(pid)
		Debug.logclr("Process killed " + str(pid), Color.DIM_GRAY)
	
	snbx_env.clean()


func _exit_tree() -> void:
	kill_sandbox()

extends Node
class_name SandboxManager

@export var gate_events: GateEvents
@export var render_result: RenderResult
@export var snbx_logger: SandboxLogger
@export var snbx_executable: SandboxExecutable
@export var snbx_env: SandboxEnv

const IPC_FOLDER := "sandbox"

var snbx_pid: int


func _ready() -> void:
	gate_events.gate_loaded.connect(start_sandbox)


func start_sandbox(gate: Gate) -> void:
	var pipe = start_process(gate)
	if pipe.is_empty(): return
	
	snbx_pid = pipe["pid"]
	snbx_logger.call_thread_safe("start", pipe, gate)
	gate_events.gate_entered_emit()


func start_process(gate: Gate) -> Dictionary:
	if not snbx_executable.exists():
		Debug.logerr("Sandbox executable not found at " + snbx_executable.path); return {}
	
	if Platform.get_platform() == Platform.WINDOWS:
		DirAccess.make_dir_recursive_absolute(IPC_FOLDER)
	
	var pack_file = ProjectSettings.globalize_path(gate.resource_pack)
	var shared_libs = ProjectSettings.globalize_path(gate.shared_libs_dir)
	var args = [
		"--main-pack", pack_file,
		"--resolution", "%dx%d" % [render_result.width, render_result.height],
		"--url", gate.url,
		"--verbose"
	]
	if not shared_libs.is_empty(): args += ["--gdext-libs-dir", shared_libs]
	
	Debug.logclr(snbx_executable.path + " " + " ".join(args), Color.DIM_GRAY)
	return OS.execute_with_pipe(snbx_executable.path, args)


func kill_sandbox() -> void:
	if OS.is_process_running(snbx_pid):
		OS.kill(snbx_pid)
		Debug.logclr("Process killed " + str(snbx_pid), Color.DIM_GRAY)
	
	snbx_logger.call_thread_safe("cleanup")


func is_process_running() -> bool:
	return OS.is_process_running(snbx_pid)


func _exit_tree() -> void:
	kill_sandbox()

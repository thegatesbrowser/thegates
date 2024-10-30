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
	match Platform.get_platform():
		Platform.WINDOWS:
			start_sandbox_windows(gate)
		Platform.LINUX_BSD:
			start_sandbox_linux(gate)
		Platform.MACOS:
			start_sandbox_macos(gate)
		_:
			assert(false, "Platform is not supported")


func start_sandbox_linux(gate: Gate) -> void:
	if not snbx_executable.exists():
		Debug.logerr("Sandbox executable not found at " + snbx_executable.path); return
	if not snbx_env.zip_exists():
		Debug.logerr("Sandbox environment not found at " + snbx_env.zip_path); return
	
	snbx_env.create_env(snbx_executable.path, gate)
	
	var args = [
		snbx_env.start.get_base_dir(), # cd to dir
		"--main-pack", snbx_env.main_pack,
		"--resolution", "%dx%d" % [render_result.width, render_result.height],
		"--verbose"
	]
	Debug.logclr(snbx_env.start + " " + " ".join(args), Color.DIM_GRAY)
	
	var pipe = OS.execute_with_pipe(snbx_env.start, args, false)
	snbx_logger.start(pipe, gate)
	snbx_pid = pipe["pid"]
	
	gate_events.gate_entered_emit()


func start_sandbox_windows(gate: Gate) -> void:
	if not snbx_executable.exists():
		Debug.logerr("Sandbox executable not found at " + snbx_executable.path); return
	
	DirAccess.make_dir_recursive_absolute(IPC_FOLDER) # TODO: move to snbx_env
	
	var pack_file = ProjectSettings.globalize_path(gate.resource_pack)
	var shared_libs = ProjectSettings.globalize_path(gate.shared_libs_dir)
	var args = [
		"--main-pack", pack_file,
		"--resolution", "%dx%d" % [render_result.width, render_result.height],
		"--verbose"
	]
	if not shared_libs.is_empty(): args += ["--gdext-libs-dir", shared_libs]
	Debug.logclr(snbx_executable.path + " " + " ".join(args), Color.DIM_GRAY)
	
	var pipe = OS.execute_with_pipe(snbx_executable.start, args, false)
	snbx_logger.start(pipe, gate)
	snbx_pid = pipe["pid"]
	
	gate_events.gate_entered_emit()


func start_sandbox_macos(gate: Gate) -> void:
	if not snbx_executable.exists():
		Debug.logerr("Sandbox executable not found at " + snbx_executable.path); return
	
	var pack_file = ProjectSettings.globalize_path(gate.resource_pack)
	var shared_libs = ProjectSettings.globalize_path(gate.shared_libs_dir)
	var args = [
		"--main-pack", pack_file,
		"--resolution", "%dx%d" % [render_result.width, render_result.height],
		"--verbose"
	]
	if not shared_libs.is_empty(): args += ["--gdext-libs-dir", shared_libs]
	Debug.logclr(snbx_executable.path + " " + " ".join(args), Color.DIM_GRAY)
	
	var pipe = OS.execute_with_pipe(snbx_executable.start, args, false)
	snbx_logger.start(pipe, gate)
	snbx_pid = pipe["pid"]
	
	gate_events.gate_entered_emit()


func kill_sandbox() -> void:
	match Platform.get_platform():
		Platform.WINDOWS:
			kill_sandbox_windows()
		Platform.LINUX_BSD:
			kill_sandbox_linux()
		Platform.MACOS:
			kill_sandbox_macos()
		_:
			assert(false, "Platform is not supported")


func kill_sandbox_linux() -> void:
	if snbx_pid == 0: return
	
	var pids = snbx_env.get_subprocesses(snbx_pid)
	pids.append(snbx_pid)
	
	for pid in pids:
		OS.kill(pid)
		Debug.logclr("Process killed " + str(pid), Color.DIM_GRAY)
	
	snbx_env.clean()


func kill_sandbox_windows() -> void:
	if OS.is_process_running(snbx_pid):
		OS.kill(snbx_pid)
		Debug.logclr("Process killed " + str(snbx_pid), Color.DIM_GRAY)


func kill_sandbox_macos() -> void:
	if OS.is_process_running(snbx_pid):
		OS.kill(snbx_pid)
		Debug.logclr("Process killed " + str(snbx_pid), Color.DIM_GRAY)


func _exit_tree() -> void:
	kill_sandbox()

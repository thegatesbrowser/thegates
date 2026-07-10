extends Node
class_name RendererManager

@export var gate_events: GateEvents
@export var render_result: RenderResult
@export var renderer_logger: RendererLogger

const EXIT_BEFORE_FRAME_GRACE_SEC = 10

var renderer_pid: int
var sandbox: Sandbox


func _ready() -> void:
	gate_events.call_or_subscribe(GateEvents.Early.ALL_LOADED, start_renderer)


func start_renderer(gate: Gate) -> void:
	var info: Dictionary = await start_process(gate)
	if info.is_empty(): return

	renderer_pid = info["pid"]
	renderer_logger.call_thread_safe("start", info, gate)
	gate_events.gate_entered_emit()


func start_process(gate: Gate) -> Dictionary:
	if not FileAccess.file_exists(gate.renderer):
		Debug.logerr("Renderer executable not found at " + gate.renderer)
		gate_events.gate_error_emit(GateEvents.GateError.MISSING_RENDERER); return {}

	var user_dir := ProjectSettings.globalize_path("user://gates_storage/" + gate_folder(gate.url))
	DirAccess.make_dir_recursive_absolute(user_dir)

	var pack_file := ProjectSettings.globalize_path(gate.resource_pack)
	var shared_libs := ProjectSettings.globalize_path(gate.shared_libs_dir)
	var args: Array[String] = [
		"--main-pack", pack_file,
		"--resolution", "%dx%d" % [render_result.width, render_result.height],
		"--url", gate.url,
		"--tg-ipc-dir", OS.get_user_data_dir(),
		"--tg-user-data-dir", user_dir,
		"--verbose"
	]
	if not shared_libs.is_empty(): args += ["--gdext-libs-dir", shared_libs]
	var driver := Platform.preferred_renderer_display_driver()
	if driver: args += ["--display-driver", driver]

	Debug.logclr(gate.renderer + " " + " ".join(args), Color.DIM_GRAY)

	var broker := Sandbox.create()
	if broker == null:
		Debug.logclr("Sandbox unavailable; renderer spawned without isolation or fd-limit raise", Debug.WARN_CLR)
		var unsandboxed := OS.execute_with_pipe(gate.renderer, args)
		if not unsandboxed.is_empty(): unsandboxed["sandboxed"] = false
		return unsandboxed

	# TODO: call broker.verify_binary(gate.renderer) once signing keys are pinned cross-platform.
	broker.apply_renderer_acl(user_dir)

	var log_path := ProjectSettings.globalize_path(RendererLogger.log_file_path(gate.url))
	DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())

	var policy := build_policy(user_dir, pack_file, shared_libs, log_path)
	var info: Dictionary = broker.spawn_target(policy, gate.renderer, args)
	if info.is_empty():
		Debug.logerr("Sandbox.spawn_target failed")
		gate_events.gate_error_emit(GateEvents.GateError.MISSING_RENDERER); return {}

	sandbox = broker
	info["sandboxed"] = true
	Debug.logclr("Sandbox target spawned pid=%s" % [info["pid"]], Color.DIM_GRAY)
	return info


func build_policy(user_dir: String, pack_file: String, shared_libs: String, log_path: String) -> SandboxPolicy:
	var launcher_dir := OS.get_user_data_dir()
	var policy := SandboxPolicy.new()
	policy.set_rw_dir(user_dir)
	policy.set_child_stdout_log_path(log_path)
	policy.set_rw_files(PackedStringArray([
		launcher_dir.path_join("command_sync"),
		launcher_dir.path_join("input_sync"),
		launcher_dir.path_join("external_texture"),
	]))
	# Launcher unlinks this between respawns — Windows AppContainer can't unlink its own bind socket.
	policy.add_renderer_bound_file(launcher_dir.path_join("external_texture"))
	var ro: PackedStringArray = [pack_file]
	if not shared_libs.is_empty(): ro.append(shared_libs) # GDExtensions load post-lockdown.
	policy.set_ro_files(ro)
	return policy


static func gate_folder(url: String) -> String:
	return url.split("?")[0].replace("http://", "").replace("https://", "").replace(".gate", "").replace(":", "_")


func send_final_logs() -> void:
	if renderer_pid == 0: return
	if not is_process_running():
		renderer_logger.send_logs("died_unnoticed")
	elif not renderer_logger.first_frame_reached:
		if Time.get_ticks_msec() - renderer_logger.start_ms < EXIT_BEFORE_FRAME_GRACE_SEC * 1000: return
		renderer_logger.send_logs("exited_before_first_frame")


func kill_renderer() -> void:
	send_final_logs()
	if sandbox != null:
		if sandbox.is_target_running():
			sandbox.kill_target()
			Debug.logclr("Sandbox target killed pid=%d" % [renderer_pid], Color.DIM_GRAY)
		sandbox = null
	elif OS.is_process_running(renderer_pid):
		OS.kill(renderer_pid)
		Debug.logclr("Process killed %d" % [renderer_pid], Color.DIM_GRAY)

	renderer_logger.call_thread_safe("cleanup")


func is_process_running() -> bool:
	if sandbox != null:
		return sandbox.is_target_running()
	return OS.is_process_running(renderer_pid)


func _exit_tree() -> void:
	kill_renderer()

extends Node
class_name RendererManager

@export var gate_events: GateEvents
@export var render_result: RenderResult
@export var renderer_logger: RendererLogger

var renderer_pid: int
var sandbox_broker: Sandbox


func _ready() -> void:
	gate_events.call_or_subscribe(GateEvents.Early.ALL_LOADED, start_renderer)


func start_renderer(gate: Gate) -> void:
	var pipe := start_process(gate)
	if pipe.is_empty(): return

	renderer_pid = pipe["pid"]
	renderer_logger.call_thread_safe("start", pipe, gate)
	gate_events.gate_entered_emit()


func start_process(gate: Gate) -> Dictionary:
	if not FileAccess.file_exists(gate.renderer):
		Debug.logerr("Renderer executable not found at " + gate.renderer); return {}

	var folder := gate_folder(gate.url)
	var user_dir := ProjectSettings.globalize_path("user://gates_storage/" + folder)
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

	Debug.logclr(gate.renderer + " " + " ".join(args), Color.DIM_GRAY)

	var broker: Sandbox = Sandbox.create()
	if broker != null and not broker.is_target():
		var verify_err: int = broker.verify_binary(gate.renderer)
		if verify_err != OK:
			Debug.logerr("Sandbox.verify_binary refused %s (err=%d); refusing to spawn" % [gate.renderer, verify_err])
			return {}

		broker.apply_renderer_acl(user_dir)

		var log_path := ProjectSettings.globalize_path("user://logs/" + folder + "/log.txt")
		DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())

		var launcher_dir := OS.get_user_data_dir()
		var policy := SandboxPolicy.new()
		policy.set_rw_dir(user_dir)
		policy.set_child_stdout_log_path(log_path)
		policy.set_rw_files(PackedStringArray([
			launcher_dir.path_join("command_sync"),
			launcher_dir.path_join("input_sync"),
			launcher_dir.path_join("external_texture"),
		]))
		policy.set_ro_files(PackedStringArray([pack_file]))

		var info: Dictionary = broker.spawn_target(policy, gate.renderer, args)
		if not info.is_empty():
			sandbox_broker = broker
			Debug.logclr("Renderer launched as sandbox target pid=%s" % [info["pid"]], Color.DIM_GRAY)
			return {"pid": info["pid"]}
		Debug.logerr("Sandbox.spawn_target failed; falling back to OS.execute_with_pipe")

	return OS.execute_with_pipe(gate.renderer, args)


static func gate_folder(url: String) -> String:
	return url.split("?")[0].replace("http://", "").replace("https://", "").replace(".gate", "").replace(":", "_")


func kill_renderer() -> void:
	if sandbox_broker != null:
		if sandbox_broker.is_target_running():
			sandbox_broker.kill_target()
			Debug.logclr("Sandbox target killed pid=%d" % [renderer_pid], Color.DIM_GRAY)
		sandbox_broker = null
	elif OS.is_process_running(renderer_pid):
		OS.kill(renderer_pid)
		Debug.logclr("Process killed %d" % [renderer_pid], Color.DIM_GRAY)

	renderer_logger.call_thread_safe("cleanup")


func is_process_running() -> bool:
	if sandbox_broker != null:
		return sandbox_broker.is_target_running()
	return OS.is_process_running(renderer_pid)


func _exit_tree() -> void:
	kill_renderer()

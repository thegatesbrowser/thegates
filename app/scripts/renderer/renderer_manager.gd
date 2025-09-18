extends Node
class_name RendererManager

@export var gate_events: GateEvents
@export var render_result: RenderResult
@export var renderer_logger: RendererLogger

const IPC_FOLDER := "renderer"

var renderer_pid: int


func _ready() -> void:
	gate_events.gate_loaded.connect(start_renderer)


func start_renderer(gate: Gate) -> void:
	var pipe = start_process(gate)
	if pipe.is_empty(): return
	
	renderer_pid = pipe["pid"]
	renderer_logger.call_thread_safe("start", pipe, gate)
	gate_events.gate_entered_emit()


func start_process(gate: Gate) -> Dictionary:
	if not FileAccess.file_exists(gate.renderer):
		Debug.logerr("Renderer executable not found at " + gate.renderer); return {}
	
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
	
	Debug.logclr(gate.renderer + " " + " ".join(args), Color.DIM_GRAY)
	return OS.execute_with_pipe(gate.renderer, args)


func kill_renderer() -> void:
	if OS.is_process_running(renderer_pid):
		OS.kill(renderer_pid)
		Debug.logclr("Process killed " + str(renderer_pid), Color.DIM_GRAY)
	
	renderer_logger.call_thread_safe("cleanup")


func is_process_running() -> bool:
	return OS.is_process_running(renderer_pid)


func _exit_tree() -> void:
	kill_renderer()

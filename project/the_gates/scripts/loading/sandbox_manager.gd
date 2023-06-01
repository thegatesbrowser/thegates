extends Node
class_name SandboxManager

@export var gate_events: GateEvents
@export var render_result: RenderResult
@export var sandbox_executable: String

var sandbox_pid: int


func _ready() -> void:
	gate_events.gate_loaded.connect(create_process)


func create_process(gate: Gate) -> void:
	var executable_dir = OS.get_executable_path().get_base_dir() + "/"
	var sandbox_path = executable_dir + sandbox_executable
	var pack_file = ProjectSettings.globalize_path(gate.resource_pack)
	
	var args = [
		"--main-pack", pack_file,
		"--resolution", "%dx%d" % [render_result.width, render_result.height],
		"--fd-path", render_result.fd_path
	]
	Debug.logclr(sandbox_path + " " + " ".join(args), Color.DARK_VIOLET)
	sandbox_pid = OS.create_process(sandbox_path, args)
	
	if OS.get_name() == "Windows": render_result.fd_path += "|" + str(sandbox_pid)
	gate_events.gate_entered_emit()


func kill_process() -> void:
	if OS.is_process_running(sandbox_pid):
		OS.kill(sandbox_pid)
		Debug.logclr("Process killed " + str(sandbox_pid), Color.DIM_GRAY)


func _exit_tree() -> void:
	kill_process()

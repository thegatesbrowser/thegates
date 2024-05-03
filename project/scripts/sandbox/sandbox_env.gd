extends Resource
class_name SandboxEnv

@export var zip: String
@export var the_gates_folder: String
@export var the_gates_folder_abs: String
@export var snbx_exe_name: String
@export var start_sh: String
@export var subprocesses_sh: String

const ENV_FOLDER := "/tmp/sandbox_env"

var zip_path: String :
	get = get_zip_path

var start: String :
	get = get_start_sh

var subprocesses: String :
	get = get_subprocesses_sh


var main_pack: String


func get_zip_path() -> String:
	var executable_dir = OS.get_executable_path().get_base_dir() + "/"
	return executable_dir + zip


func get_start_sh() -> String:
	return ProjectSettings.globalize_path(ENV_FOLDER + "/" + start_sh)


func get_subprocesses_sh() -> String:
	return ProjectSettings.globalize_path(ENV_FOLDER + "/" + subprocesses_sh)


func zip_exists() -> bool:
	return FileAccess.file_exists(zip_path)


func create_env(snbx_executable: String, gate: Gate) -> void:
	Debug.logclr("create_env %s" % [ENV_FOLDER], Color.DIM_GRAY)
	UnZip.unzip(zip_path, ENV_FOLDER, true)
	
	var folder = ENV_FOLDER + "/" + the_gates_folder
	var executable = folder + "/" + snbx_exe_name
	DirAccess.copy_absolute(snbx_executable, executable)
	
	main_pack = executable.get_basename() + "." + gate.resource_pack.get_extension()
	DirAccess.copy_absolute(gate.resource_pack, main_pack)
	main_pack = the_gates_folder_abs + "/" + main_pack.get_file()
	
	if not gate.shared_libs_dir.is_empty() and DirAccess.dir_exists_absolute(gate.shared_libs_dir):
		for file in DirAccess.get_files_at(gate.shared_libs_dir):
			var lib = gate.shared_libs_dir + "/" + file
			var lib_in_folder = folder + "/" + file
			DirAccess.copy_absolute(lib, lib_in_folder)
			Debug.logclr(lib_in_folder, Color.DIM_GRAY)


func get_subprocesses(ppid: int) -> Array[int]:
	var pids: Array[int] = []
	var output = []
	
	OS.execute(subprocesses, [str(ppid)], output)
	if output.is_empty(): return pids
	
	var s_pids = output[0].split('\n')
	for s_pid in s_pids:
		if s_pid.is_empty(): continue
		var pid = s_pid.to_int()
		pids.append(pid)
	
	return pids


func clean() -> void:
	OS.execute("rm", ["-rf", ProjectSettings.globalize_path(ENV_FOLDER)])

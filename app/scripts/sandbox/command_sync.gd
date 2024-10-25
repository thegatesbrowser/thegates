extends CommandSync

@export var gate_events: GateEvents
@export var command_events: CommandEvents


func _ready() -> void:
	gate_events.gate_entered.connect(bind)
	execute_function = _execute_function


func _physics_process(_delta: float) -> void:
	receive_commands()


func _execute_function(command: Command) -> Variant:
	Debug.logclr("Recieved command: " + command.name + ". Args: " + str(command.args), Color.SANDY_BROWN)
	match command.name:
		"send_filehandle":
			if wrong_args_count(command, 1): return ERR_INVALID_PARAMETER
			command_events.send_filehandle_emit(command.args[0])
			
		"ext_texture_format":
			if wrong_args_count(command, 1): return ERR_INVALID_PARAMETER
			command_events.ext_texture_format_emit(command.args[0])
			
		"first_frame_drawn":
			if wrong_args_count(command, 0): return ERR_INVALID_PARAMETER
			gate_events.first_frame_emit()
			
		"set_mouse_mode":
			if wrong_args_count(command, 1): return ERR_INVALID_PARAMETER
			command_events.set_mouse_mode_emit(command.args[0])
			
		"open_gate":
			if wrong_args_count(command, 1): return ERR_INVALID_PARAMETER
			var url = Url.join(gate_events.current_gate_url, command.args[0])
			gate_events.open_gate_emit(url)
			
		"open_link":
			if wrong_args_count(command, 1): return ERR_INVALID_PARAMETER
			OS.shell_open(command.args[0])
			
		_:
			Debug.logerr("Command %s not implemented" % [command.name])
			return ERR_METHOD_NOT_FOUND
	
	return OK


func wrong_args_count(command: Command, right_count: int) -> bool:
	var count = command.args.size()
	if count != right_count:
		Debug.logerr("Command %s args count should be %d but it's %d" % [command.name, right_count, count])
		return true
	
	return false

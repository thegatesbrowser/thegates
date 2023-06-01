extends CommandSync

@export var gate_events: GateEvents
@export var command_events: CommandEvents


func _ready() -> void:
	gate_events.gate_entered.connect(bind)
	execute_function = _execute_function


func _physics_process(_delta: float) -> void:
	receive_commands()


func _execute_function(command: Command) -> Variant:
	Debug.logclr("Recieved command: " + command.name, Color.SANDY_BROWN)
	match command.name:
		"send_filehandle":
			command_events.send_filehandle_emit()
		"set_mouse_mode":
			if command.args.size() != 1: Debug.logerr("Arg count should be 1"); return ""
			command_events.set_mouse_mode_emit(command.args[0])
		"open_gate":
			if command.args.size() != 1: Debug.logerr("Arg count should be 1"); return ""
			var url = Url.join(gate_events.current_gate_url, command.args[0])
			gate_events.open_gate_emit(url)
		_:
			Debug.logerr("Command %s not implemented" % [command.name])
	return ""

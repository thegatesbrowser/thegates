extends CommandSync

@export var gate_events: GateEvents
@export var command_events: CommandEvents


func _ready() -> void:
	gate_events.gate_entered.connect(bind)
	execute_function = _execute_function


func _physics_process(delta: float) -> void:
	receive_commands()


func _execute_function(command: String) -> String:
	print("Recieved command: " + command)
	match command:
		"send_fd":
			command_events.send_fd_emit()
		_:
			print("Command %s not implemented" % [command])
	return ""

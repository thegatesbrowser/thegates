extends RoundButton

@export var url: String


func _ready() -> void:
	super._ready()
	
	pressed.connect(open_help_url)


func open_help_url() -> void:
	OS.shell_open(url)

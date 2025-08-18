extends RoundButton

@export var url: String
@export var app_events: AppEvents


func _ready() -> void:
	super._ready()
	
	pressed.connect(open_help_url)


func open_help_url() -> void:
	app_events.open_link_emit(url)

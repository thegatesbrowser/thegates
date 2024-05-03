extends Label

@export var gate_events: GateEvents


func _ready() -> void:
	gate_events.gate_info_loaded.connect(func(_gate, _is_cached): on_gate_info_loaded())
	gate_events.gate_entered.connect(on_gate_entered)
	gate_events.gate_error.connect(on_gate_error)
	set_text("Connecting...")


func on_gate_info_loaded() -> void:
	gate_events.download_progress.connect(show_progress)


func show_progress(_url: String, body_size: int, downloaded_bytes: int) -> void:
	var percent = int(downloaded_bytes * 100 / body_size)
	set_text("Downloading: %d%s" % [percent, "%"])


func on_gate_entered() -> void:
	gate_events.download_progress.disconnect(show_progress)
	set_text("")


func on_gate_error(code: GateEvents.GateError) -> void:
	match code:
		GateEvents.GateError.NOT_FOUND:
			set_text("Gate not found")
		GateEvents.GateError.MISSING_PACK, GateEvents.GateError.MISSING_LIBS:
			set_text("Cannot load gate resources")
		_:
			set_text("Error")

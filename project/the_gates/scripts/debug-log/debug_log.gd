extends RichTextLabel


func _ready() -> void:
	Debug.logged.connect(add_log)


func add_log(msg: String) -> void:
	append_text(msg + "\n")

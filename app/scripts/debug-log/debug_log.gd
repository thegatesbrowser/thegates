extends RichTextLabel


func _ready() -> void:
	Debug.logged.connect(add_log)
	meta_clicked.connect(on_meta_clicked)


func add_log(msg: String) -> void:
	append_text(msg + "\n")


func on_meta_clicked(meta) -> void:
	OS.shell_open(str(meta))

extends RichTextLabel


func _ready() -> void:
	finished.connect(to_line)


func to_line() -> void:
	text = text.replace('\n', '\t') # TODO: Handle BBCode

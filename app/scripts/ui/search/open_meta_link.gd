extends RichTextLabel

@export var app_events: AppEvents


func _ready() -> void:
	meta_clicked.connect(on_meta_clicked)


func on_meta_clicked(meta) -> void:
	app_events.open_link_emit(str(meta))

extends Node

@export var api: ApiSettings
@export var bookmarks: Bookmarks


func _ready() -> void:
	bookmarks.on_ready.connect(on_bookmarks_ready)


func on_bookmarks_ready() -> void:
	if bookmarks.gates.size() > 0: return
	# TODO: Get featured gates

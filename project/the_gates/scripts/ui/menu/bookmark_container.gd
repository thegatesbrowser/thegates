extends HBoxContainer

@export var bookmarks: Bookmarks
@export var bookmark_scene: PackedScene


func _ready() -> void:
	for gate in bookmarks.gates.values():
		var bookmark: BookmarkUI = bookmark_scene.instantiate()
		bookmark.fill(gate)
		add_child(bookmark)

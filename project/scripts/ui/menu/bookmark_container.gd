extends GridContainer

@export var bookmarks: Bookmarks
@export var bookmark_scene: PackedScene


func _ready() -> void:
	bookmarks.on_star.connect(show_bookmark)
	for gate in bookmarks.gates.values():
		show_bookmark(gate)


func show_bookmark(gate: Gate) -> void:
	var bookmark: BookmarkUI = bookmark_scene.instantiate()
	bookmark.fill(gate)
	add_child(bookmark)

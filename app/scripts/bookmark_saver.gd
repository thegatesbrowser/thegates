extends Node

@export_dir var save_dir: String
@export_dir var icon_save_dir: String
@export var bookmarks: Bookmarks

@onready var path = save_dir + "/" + bookmarks.resource_path.get_file()


func _ready() -> void:
	load_bookmarks()
	bookmarks.ready()
	
	bookmarks.save_icon.connect(save_icon)
	bookmarks.on_star.connect(func(_gate, _featured): save_bookmarks())
	bookmarks.on_unstar.connect(func(_gate): save_bookmarks())
	bookmarks.on_update.connect(func(_gate): save_bookmarks())


func load_bookmarks() -> void:
	if not FileAccess.file_exists(path): return
	
	var loaded = ResourceLoader.load(path) as Bookmarks
	if loaded == null: return
	
	bookmarks.starred_gates = loaded.starred_gates


func save_bookmarks() -> void:
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	ResourceSaver.save(bookmarks, path)


func save_icon(gate: Gate) -> void:
	if not FileAccess.file_exists(gate.icon): return
	if not DirAccess.dir_exists_absolute(icon_save_dir):
		DirAccess.make_dir_recursive_absolute(icon_save_dir)
	
	var new_path = icon_save_dir + "/" + gate.icon.get_file()
	if new_path == gate.icon: return
	DirAccess.copy_absolute(gate.icon, new_path)
	gate.icon = new_path


func clear_icon_folder() -> void:
	if not DirAccess.dir_exists_absolute(icon_save_dir): return
	
	var used_icons: Array[String] = []
	for gate in bookmarks.gates.values():
		used_icons.append(gate.icon.get_file())
	
	for file in DirAccess.get_files_at(icon_save_dir):
		if not file in used_icons:
			DirAccess.remove_absolute(icon_save_dir + "/" + file)


func _exit_tree() -> void:
	save_bookmarks()
	clear_icon_folder()

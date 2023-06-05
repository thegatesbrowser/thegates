extends Node

@export_dir var save_dir: String
@export_dir var image_save_dir: String
@export var bookmarks: Bookmarks

@onready var path = save_dir + "/" + bookmarks.resource_path.get_file()


func _ready() -> void:
	load_bookmarks()
	bookmarks.ready()
	bookmarks.save_image.connect(save_image)


func load_bookmarks() -> void:
	if not FileAccess.file_exists(path): return
	var loaded = ResourceLoader.load(path) as Bookmarks
	if loaded == null: return
	
	bookmarks.featured_gates = loaded.featured_gates
	bookmarks.starred_gates = loaded.starred_gates


func save_bookmarks() -> void:
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)
	ResourceSaver.save(bookmarks, path)


func save_image(gate: Gate) -> void:
	if not FileAccess.file_exists(gate.image): return
	if not DirAccess.dir_exists_absolute(image_save_dir):
		DirAccess.make_dir_recursive_absolute(image_save_dir)
	
	var new_path = image_save_dir + "/" + gate.image.get_file()
	if new_path == gate.image: return
	DirAccess.copy_absolute(gate.image, new_path)
	gate.image = new_path


func clear_image_folder() -> void:
	if not DirAccess.dir_exists_absolute(image_save_dir): return
	
	var used_images: Array[String] = []
	for gate in bookmarks.gates.values(): used_images.append(gate.image.get_file())
	
	for file in DirAccess.get_files_at(image_save_dir):
		if not file in used_images:
			DirAccess.remove_absolute(image_save_dir + "/" + file)


func _exit_tree() -> void:
	save_bookmarks()
	clear_image_folder()

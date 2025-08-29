extends Node
class_name FileTools


static func remove_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path) and not FileAccess.file_exists(path): return
	
	var dir = DirAccess.open(path)
	if dir:
		# List directory content
		var err : Error
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				remove_recursive(path + "/" + file_name)
			else:
				err = dir.remove(file_name)
				if err != OK: Debug.logerr("Error removing: " + path + "/" + file_name)
			file_name = dir.get_next()
		
		# Remove current path
		err = dir.remove(path)
		if err != OK: Debug.logerr("Error removing: " + path)
	else:
		Debug.logerr("Error removing " + path)


static func load_external_tex(path: String) -> Texture2D:
	if path.begins_with("res://"): return load(path)
	if not FileAccess.file_exists(path): return null
	
	var image = Image.load_from_file(path)
	if not is_instance_valid(image): return null
	return ImageTexture.create_from_image(image) as Texture2D

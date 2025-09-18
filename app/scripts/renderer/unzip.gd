extends Node
class_name UnZip


static func unzip(zip_path: String, to_folder: String, contains_symlink: bool = false) -> void:
	var reader = ZIPReader.new()
	var err = reader.open(zip_path)
	if err != OK: Debug.logerr("Cannot open file %s to unzip" % [zip_path]); return
	
	for path in reader.get_files():
		if path.get_file().is_empty(): # is directory
			DirAccess.make_dir_recursive_absolute(to_folder + "/" + path)
#			Debug.logclr("makedir %s" % [to_folder + "/" + path], Color.DIM_GRAY)
		else:
			create_file(reader, path, to_folder, contains_symlink)


static func create_file(reader: ZIPReader, path: String, folder: String, contains_symlink: bool) -> void:
	var data = reader.read_file(path)
	var symlink = ""
	
	if contains_symlink:
		symlink = data.get_string_from_utf8()
		if symlink.split("\n").size() != 1:
			symlink = ""
	
	if contains_symlink and symlink.is_absolute_path():
		var link_to = ProjectSettings.globalize_path(folder + "/" + path.get_basename())
		OS.execute("ln", ["-s", symlink, link_to])
#		Debug.logclr("ln -s %s %s" % [symlink, link_to], Color.DIM_GRAY)
	else:
		var file_path = folder + "/" + path
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		file.store_buffer(data)
		file.close()
		if file_path.get_extension() == "sh":
			OS.execute("chmod", ["+x", ProjectSettings.globalize_path(file_path)])
#		Debug.logclr("touch %s" % [folder + "/" + path], Color.DIM_GRAY)

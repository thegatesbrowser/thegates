extends Node
class_name UnZip


static func extract_renderer_files(renderer_zip: String, renderer_path: String) -> bool:
	var reader = ZIPReader.new()
	var err = reader.open(renderer_zip)
	if err != OK: Debug.logclr("Cannot open file %s to unzip" % [renderer_zip], Color.RED); return false
	
	if not reader.file_exists(renderer_path.get_file()):
		Debug.logclr("Renderer file %s not found in zip %s" % [renderer_path.get_file(), renderer_zip], Color.RED); return false
	DirAccess.make_dir_recursive_absolute(renderer_path.get_base_dir())
	
	for filename in reader.get_files():
		if filename.contains("__MACOSX"): continue
		
		var file_path = renderer_path.get_base_dir() + "/" + filename
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file == null: Debug.logclr("Cannot open file %s to write" % [file_path], Color.RED); return false
		
		var buffer = reader.read_file(filename)
		if not file.store_buffer(buffer): Debug.logclr("Cannot write to file %s" % [file_path], Color.RED); return false
		file.close()
	
	FileAccess.set_unix_permissions(renderer_path, FileAccess.get_unix_permissions(renderer_path) | FileAccess.UNIX_EXECUTE_OWNER)
	reader.close()
	
	return true

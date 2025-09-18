extends Node
class_name UnZip


static func extract_file(zip: String, to_path: String, executable: bool = false) -> bool:
	var reader = ZIPReader.new()
	var err = reader.open(zip)
	if err != OK: Debug.logclr("Cannot open file %s to unzip" % [zip], Color.RED); return false
	
	if not reader.file_exists(to_path.get_file()):
		Debug.logclr("File %s not found in zip %s" % [to_path.get_file(), zip], Color.RED); return false
	
	var buffer = reader.read_file(to_path.get_file())
	var file = FileAccess.open(to_path, FileAccess.WRITE)
	if file == null: Debug.logclr("Cannot open file %s to write" % [to_path], Color.RED); return false
	
	if not file.store_buffer(buffer): Debug.logclr("Cannot write to file %s" % [to_path], Color.RED); return false
	
	file.close()
	reader.close()
	
	if executable:
		FileAccess.set_unix_permissions(to_path, FileAccess.get_unix_permissions(to_path) | FileAccess.UNIX_EXECUTE_OWNER)
	
	return true

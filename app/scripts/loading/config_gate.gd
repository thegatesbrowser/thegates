extends ConfigBase
class_name ConfigGate

const SECTION = "gate"

var title: String
var description: String
var image_url: String
var resource_pack_url: String
var libraries: PackedStringArray


func _init(path: String, base_url: String) -> void:
	super._init(path)
	title = get_string(SECTION, "title")
	description = get_string(SECTION, "description")
	image_url = Url.join(base_url, get_string(SECTION, "image"))
	resource_pack_url = Url.join(base_url, get_string(SECTION, "resource_pack"))
	libraries = get_libraries(base_url)


func get_libraries(base_url: String) -> PackedStringArray:
	var unsplit_libs = GDExtension.find_extension_library("", config)
	if unsplit_libs.is_empty(): return []
	
	var libs = unsplit_libs.split(";")
	for i in range(libs.size()): libs[i] = Url.join(base_url, libs[i])
	return libs

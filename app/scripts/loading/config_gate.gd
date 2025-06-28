extends ConfigBase
class_name ConfigGate

const SECTION = "gate"

const KEY_TITLE = "title"
const KEY_DESCRIPTION = "description"
const KEY_ICON = "icon"
const KEY_IMAGE = "image"
const KEY_RESOURCE_PACK = "resource_pack"
const KEY_DISCOVERABLE = "discoverable"

var title: String
var description: String
var icon_url: String
var image_url: String
var resource_pack_url: String
var discoverable: bool
var libraries: PackedStringArray


func _init(path: String, base_url: String) -> void:
	super._init(path)
	title = get_string(SECTION, KEY_TITLE)
	description = get_string(SECTION, KEY_DESCRIPTION)
	icon_url = Url.join(base_url, get_string(SECTION, KEY_ICON))
	image_url = Url.join(base_url, get_string(SECTION, KEY_IMAGE))
	resource_pack_url = Url.join(base_url, get_string(SECTION, KEY_RESOURCE_PACK))
	discoverable = get_value(SECTION, KEY_DISCOVERABLE, true)
	libraries = get_libraries(base_url)


func get_libraries(base_url: String) -> PackedStringArray:
	var unsplit_libs = GDExtension.find_extension_library("", config)
	if unsplit_libs.is_empty(): return []
	
	var libs = unsplit_libs.split(";")
	for i in range(libs.size()): libs[i] = Url.join(base_url, libs[i])
	return libs

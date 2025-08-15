extends Resource
class_name Gate

@export var url: String:
	set(value): url = Url.fix_gate_url(value)

@export var title: String
@export var description: String
@export var icon_url: String
@export var image_url: String
@export var icon: String
@export var image: String

# Only for featured gates. Cleared when opened
@export var featured: bool
@export var is_special: bool

var resource_pack: String
var shared_libs_dir: String # local path where libs downloaded


static func create(_url: String, _title: String, _description: String, _icon_url: String, _image_url: String) -> Gate:
	var gate = Gate.new()
	gate.url = _url
	gate.title = _title
	gate.description = _description
	gate.icon_url = _icon_url
	gate.image_url = _image_url
	return gate

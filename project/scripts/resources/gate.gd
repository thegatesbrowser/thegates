extends Resource
class_name Gate

@export var url: String:
	set(value): url = Url.fix_gate_url(value)

@export var title: String
@export var description: String
@export_file("*.png", "*.jpg") var image: String
var resource_pack: String
var shared_libs_dir: String


static func create(_url: String, _title: String, _description: String,
		_image: String, _resource_pack: String, _shared_libs_dir: String) -> Gate:
	var gate = Gate.new()
	gate.url = _url
	gate.title = _title
	gate.description = _description
	gate.image = _image
	gate.resource_pack = _resource_pack
	gate.shared_libs_dir = _shared_libs_dir
	return gate

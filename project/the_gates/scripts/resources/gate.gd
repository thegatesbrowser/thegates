extends Resource
class_name Gate

@export var url: String:
	set(value): url = Url.fix_gate_url(value)

@export var title: String
@export var description: String
@export_file("*.png", "*.jpg") var image: String
var godot_config: String
var global_script_class: String
var resource_pack: String


static func create(_url: String, _title: String, _description: String,
		_image: String, _godot_config: String, _global_script_class: String, _resource_pack: String) -> Gate:
	var gate = Gate.new()
	gate.url = _url
	gate.title = _title
	gate.description = _description
	gate.image = _image
	gate.godot_config = _godot_config
	gate.global_script_class = _global_script_class
	gate.resource_pack = _resource_pack
	return gate

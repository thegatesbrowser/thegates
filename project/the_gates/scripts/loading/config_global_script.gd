extends ConfigBase
class_name ConfigGlobalScript

# for unloading
var scripts


func _init(path: String) -> void:
	super._init(path)


func load_config() -> void:
	load_global_classes()


func unload_config() -> void:
	unload_global_classes()


func load_global_classes() -> void:
	scripts = get_value("", "list")
	if scripts == null: return
	for script in scripts: CppExposed.add_global_class(script)


func unload_global_classes() -> void:
	if scripts == null: return
	for script in scripts: CppExposed.remove_global_class(script)

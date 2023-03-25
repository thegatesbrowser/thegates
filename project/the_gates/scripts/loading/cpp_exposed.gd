extends Node
class_name CppExposed


static func add_global_class(script) -> void:
	ScriptServerExposed.add_global_class(
		script["class"], script["base"], script["language"], script["path"])


static func remove_global_class(script) -> void:
	ScriptServerExposed.remove_global_class(script["class"])


static func print_global_classes() -> void:
#	ProjectSettings.get_global_class_list() // Can be replaced with this
	var global_classes = ScriptServerExposed.get_global_class_list()
	Debug.logr("Global classes: " + str(global_classes))


static func add_autoload(autoload: String, path: String) -> void:
	var is_singleton = false
	if path.begins_with("*"):
		path = path.trim_prefix("*")
		is_singleton = true
	ProjectSettingsExposed.add_autoload(autoload, path, is_singleton)


static func remove_autoload(autoload: String) -> void:
	ProjectSettingsExposed.remove_autoload(autoload)


static func print_autoloads() -> void:
	var autoloads = ProjectSettingsExposed.get_autoload_list()
	Debug.logr("Autoloads: " + str(autoloads))

extends ConfigBase
class_name ConfigGodot

var scene_path: String

# for unloading
var autoloads
var actions


func _init(path: String) -> void:
	super._init(path)
	scene_path = get_string("application", "run/main_scene")


func load_config() -> void:
	load_autoloads()
	load_input_map()


func unload_config() -> void:
	unload_autoloads()
	unload_input_map()


func load_autoloads() -> void:
	autoloads = get_section_keys("autoload")
	if autoloads == null: return
	for autoload in autoloads:
		var path = get_value("autoload", autoload)
		CppExposed.add_autoload(autoload, path)


func unload_autoloads() -> void:
	if autoloads == null: return
	for autoload in autoloads:
		CppExposed.remove_autoload(autoload)


func load_input_map() -> void:
	actions = get_section_keys("input")
	if actions == null: return
	for action_name in actions:
		var action = get_value("input", action_name)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, action["deadzone"])
		for event in action["events"]:
			if not event is InputEvent: continue
			InputMap.action_add_event(action_name, event)


func unload_input_map() -> void:
	if actions == null: return
	for action_name in actions: Input.action_release(action_name)
	InputMap.load_from_project_settings()

extends ConfigBase
class_name PackConfig

var scene_path: String

# for unloading
var scripts
var autoloads
var actions


func _init(path: String) -> void:
	super._init(path)
	scene_path = get_string("application", "run/main_scene")


func load_config() -> void:
	load_global_classes()
	load_autoloads()
	load_input_map()
	load_settings()


func unload_config() -> void:
	unload_global_classes()
	unload_autoloads()
	unload_input_map()


func load_global_classes() -> void:
	scripts = get_value("", "_global_script_classes")
	if scripts == null: return
	for script in scripts: CppExposed.add_global_class(script)


func unload_global_classes() -> void:
	if scripts == null: return
	for script in scripts: CppExposed.remove_global_class(script)


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


func load_settings() -> void:
	var sections := get_sections()
	for section in sections:
		if section in ["application"]: continue
		Debug.logclr(section, Color.GREEN)
		var keys := get_section_keys(section)
		for key in keys:
			var value = get_value(section, key)
			ProjectSettings.set_setting(key, value)
			Debug.logclr(ProjectSettings.get_setting(key), Color.DARK_SEA_GREEN)

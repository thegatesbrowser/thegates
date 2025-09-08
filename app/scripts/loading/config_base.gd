extends Node
class_name ConfigBase

var config: ConfigFile
var config_path: String
var load_result: Error


func _init(path: String) -> void:
	config = ConfigFile.new()
	load_result = config.load(path)
	config_path = path


func get_string(section: String, key: String) -> String:
	var value: String
	if config.has_section_key(section, key):
		value = config.get_value(section, key)
#		Debug.logr(key + "=" + value)
	else: Debug.logclr("don't have section " + section + ", key " + key, Color.GRAY)
	return value


func get_value(section: String, key: String, default: Variant = null) -> Variant:
	var value: Variant = default
	if config.has_section_key(section, key):
		value = config.get_value(section, key)
#		Debug.logr(key + "=" + str(value))
	else: Debug.logclr("don't have section " + section + ", key " + key, Color.GRAY)
	return value


func get_sections() -> PackedStringArray:
	return config.get_sections()


func get_section_keys(section: String) -> PackedStringArray:
	var keys: PackedStringArray
	if config.has_section(section):
		keys = config.get_section_keys(section)
#		Debug.logr(keys)
	else: Debug.logclr("don't have section " + section, Color.GRAY)
	return keys


func set_value(section: String, key: String, value: Variant) -> void:
	config.set_value(section, key, value)

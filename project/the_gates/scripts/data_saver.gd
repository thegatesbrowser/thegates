extends ConfigBase

var path: String = "user://resources/data_saver.cfg"


func _init() -> void:
	super._init(path)


func save_data() -> void:
	config.save(config_path)


func _exit_tree() -> void:
	save_data()

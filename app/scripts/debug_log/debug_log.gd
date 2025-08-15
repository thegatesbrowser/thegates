extends RichTextLabel

const APP_NAME: String = "TheGates"
const WEB_SITE: String = "https://thegates.io"


func _ready() -> void:
	Debug.logged.connect(add_log)
	meta_clicked.connect(on_meta_clicked)
	
	print_app_info()


func add_log(msg: String) -> void:
	append_text(msg + "\n")


func on_meta_clicked(meta) -> void:
	OS.shell_open(str(meta))


func print_app_info() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version")
	var platform: String = OS.get_name()
	Debug.logr("%s %s v%s - [url]%s[/url]" % [APP_NAME, platform, version, WEB_SITE])

extends Node

@export var gate_events: GateEvents
@export var api: ApiSettings
@export var home: PackedScene
@export var search_results: PackedScene
@export var world_scene: PackedScene
@export var scenes_root: Node

const API_URL_ARG := "--api-url"
const QUIT_FLUSH_TIMEOUT_SEC = 3.0

var is_quitting: bool


func _ready() -> void:
	apply_api_override()

	if NetworkDiagnostic.is_enabled():
		NetworkDiagnostic.run_and_quit()
		return

	if not Autotest.is_enabled():
		Platform.notify_x11_sandbox_caveat()

	get_tree().auto_accept_quit = false

	gate_events.search.connect(func(_query): switch_scene(search_results))
	gate_events.open_gate_app.connect(func(_url): switch_scene(world_scene))
	gate_events.exit_gate.connect(func(): switch_scene(home))

	switch_scene(home)

	Autotest.attach(self, gate_events)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: quit_app()


func switch_scene(scene: PackedScene) -> void:
	for child in scenes_root.get_children(): child.queue_free()
	scenes_root.add_child(scene.instantiate())


# freeing the world dispatches pending crash-log uploads; flush before quit
func quit_app() -> void:
	if is_quitting:
		get_tree().quit()
		return
	is_quitting = true

	for child in scenes_root.get_children(): child.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await Backend.flush(QUIT_FLUSH_TIMEOUT_SEC)
	get_tree().quit()


func apply_api_override() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty(): args = OS.get_cmdline_args()
	var idx := args.find(API_URL_ARG)
	if idx == -1 or idx + 1 >= args.size(): return

	api.local_url = args[idx + 1]
	api.host_type = ApiSettings.HostType.Local
	Debug.logclr("API url override: " + api.url, Debug.WARN_CLR)

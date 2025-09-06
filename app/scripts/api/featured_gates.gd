extends Node

const KEY_URL = "url"
const KEY_TITLE = "title"
const KEY_DESCRIPTION = "description"
const KEY_ICON = "icon"
const KEY_IS_SPECIAL = "is_special"

@export var api: ApiSettings
@export var bookmarks: Bookmarks

var result_str: String = "{}"


func _ready() -> void:
	bookmarks.on_ready.connect(on_bookmarks_ready)
	if bookmarks.is_ready: on_bookmarks_ready()


func on_bookmarks_ready() -> void:
	if bookmarks.gates.size() > 0: return
	
	await featured_gates_request()
	Debug.logclr("======== Featured gates ========", Color.LIGHT_SEA_GREEN)
	
	var gates = JSON.parse_string(result_str)
	if gates == null or gates.is_empty():
		Debug.logclr("No featured gates found", Color.YELLOW)
		return
	
	for gate in gates:
		Debug.logr(gate["url"])
		star_gate(gate)


func featured_gates_request() -> void:
	var callback = func(_result, code, _headers, body):
		if code == 200:
			result_str = body.get_string_from_utf8()
		else: Debug.logclr("Featured gates request failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(api.featured_gates, callback)
	if err != OK: Debug.logclr("Cannot send featured gates request", Color.RED)


func star_gate(gate_d: Dictionary) -> void:
	var gate = Gate.create(gate_d[KEY_URL], gate_d[KEY_TITLE], gate_d[KEY_DESCRIPTION], gate_d[KEY_ICON], "")
	gate.is_special = gate_d[KEY_IS_SPECIAL]
	gate.featured = true
	bookmarks.star(gate)
	
	var icon = await FileDownloader.download(gate.icon_url)
	bookmarks.update_icon(gate.url, icon)

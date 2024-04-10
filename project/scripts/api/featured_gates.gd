extends Node

@export var api: ApiSettings
@export var bookmarks: Bookmarks

var result_str: String = "{}"


func _ready() -> void:
	bookmarks.on_ready.connect(on_bookmarks_ready)
	if bookmarks.is_ready: on_bookmarks_ready()


func on_bookmarks_ready() -> void:
	if bookmarks.gates.size() > 0: return
	
	await featured_gates_request()
	Debug.logclr("Featured gates requested", Color.LIGHT_SEA_GREEN)
	
	var gates = JSON.parse_string(result_str)
	if gates == null or gates.is_empty():
		Debug.logclr("No featured gates found", Color.YELLOW)
		return
	
	for gate in gates:
		# TODO: download image and add to bookmarks
		Debug.logr(gate["url"])


func featured_gates_request() -> void:
	var callback = func(_result, code, _headers, body):
		if code == 200:
			result_str = body.get_string_from_utf8()
		else: Debug.logclr("Featured gates request failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(api.featured_gates, callback)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send featured gates request", Color.RED)

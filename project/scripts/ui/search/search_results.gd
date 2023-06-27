extends VBoxContainer

@export var gate_events: GateEvents
@export var api: ApiSettings
@export var result_scene: PackedScene

var result_str: String


func _ready() -> void:
	search(gate_events.current_search_query)


func search(query: String) -> void:
	Debug.logclr("======== " + query + " ========", Color.LIGHT_SEA_GREEN)
	await search_request(query)
	
	var gates = JSON.parse_string(result_str)
	if gates == null or gates.is_empty():
		Debug.logclr("No gates found", Color.YELLOW)
		return
	
	for gate in gates:
		var result: SearchResult = result_scene.instantiate()
		result.fill(gate)
		add_child(result)
		Debug.logr(gate["url"])


func search_request(query: String):
	var url = api.search + query.uri_encode()
	var callback = func(_result, code, _headers, body):
		if code == 200:
			result_str = body.get_string_from_utf8()
		else: Debug.logclr("Request search failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request search", Color.RED)

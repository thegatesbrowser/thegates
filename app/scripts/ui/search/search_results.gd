extends VBoxContainer

@export var gate_events: GateEvents
@export var api: ApiSettings
@export var result_scene: PackedScene

var result_str: String = "{}"
var suggestions_str: String = "{}"

func _ready() -> void:
	search(gate_events.current_search_query)


func search(query: String) -> void:
	Debug.logclr("======== " + query + " ========", Color.LIGHT_SEA_GREEN)
	await search_request(query)
	
	var gates = JSON.parse_string(result_str)
	if gates == null or gates.is_empty():
		Debug.logclr("No gates found, request suggestions", Color.YELLOW)
		suggestions()
		return
	
	for gate in gates:
		Debug.logr(gate["url"])
		var result: SearchResult = result_scene.instantiate()
		result.fill(gate)
		add_child(result)


func search_request(query: String) -> void:
	var url = api.search + query.uri_encode()
	var callback = func(_result, code, _headers, body):
		if code == 200:
			result_str = body.get_string_from_utf8()
		else: Debug.logclr("Request search failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request search", Color.RED)


func suggestions() -> void:
	await suggestions_request()
	
	var suggs = JSON.parse_string(suggestions_str)
	if suggs == null or suggs.is_empty():
		Debug.logclr("No suggestions found", Color.YELLOW)
		return
	
	for sugg in suggs:
		Debug.logr(sugg)


func suggestions_request() -> void:
	var url = api.search_suggestions
	var callback = func(_result, code, _headers, body):
		if code == 200:
			suggestions_str = body.get_string_from_utf8()
		else: Debug.logclr("Request search suggestions failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request search suggestions", Color.RED)

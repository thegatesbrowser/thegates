extends VBoxContainer

@export var gate_events: GateEvents
@export var api: ApiSettings

var result: String


func _ready() -> void:
	search(gate_events.current_search_query)


func search(query: String) -> void:
	Debug.logclr("======== " + query + " ========", Color.LIGHT_SEA_GREEN)
	await search_request(query)
	
	var gates = JSON.parse_string(result)
	if gates == null or gates.is_empty():
		Debug.logclr("No gates found", Color.YELLOW)
		return
	
	for gate in gates:
		var url = gate["url"]
		var title = gate["title"]
		var image = gate["image"]
		var description = gate["description"]
		Debug.logr(gate)


#func add_result()


func search_request(query: String):
	var url = api.search + query.uri_encode()
	var callback = func(_result, code, _headers, body):
		if code == 200:
			result = body.get_string_from_utf8()
		else: Debug.logclr("Request search failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request search", Color.RED)

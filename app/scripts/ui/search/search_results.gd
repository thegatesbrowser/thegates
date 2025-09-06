extends VBoxContainer

@export var gate_events: GateEvents
@export var api: ApiSettings
@export var result_scene: PackedScene

@export var header: SearchResultsHeader
@export var suggestions_root: Control
@export var suggestion_scene: PackedScene
@export var no_results_note: PackedScene

var result_str: String = "{}"
var cancel_callbacks: Array = []


func _ready() -> void:
	search(gate_events.current_search_query)


func search(query: String) -> void:
	Debug.logclr("======== " + query + " ========", Color.LIGHT_SEA_GREEN)
	await search_request(query)
	
	var result = JSON.parse_string(result_str)
	var gates = JSON.parse_string(result["gates"])
	
	if gates == null or gates.is_empty():
		Debug.logclr("No gates found, showing suggestions", Color.YELLOW)
		var suggs = JSON.parse_string(result["suggestions"])
		suggestions(suggs)
		return
	
	header.set_search_header()
	suggestions_root.visible = false
	
	for gate in gates:
		Debug.logr(gate["url"])
		var search_result: SearchResult = result_scene.instantiate()
		search_result.fill(gate)
		add_child(search_result)


func search_request(query: String) -> void:
	var url = api.search + query.uri_encode()
	var callback = func(_result, code, _headers, body):
		if code == 200:
			result_str = body.get_string_from_utf8()
		else: Debug.logclr("Request search failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback, {}, HTTPClient.METHOD_GET, cancel_callbacks)
	if err != OK: Debug.logclr("Cannot send request search", Color.RED)


func suggestions(suggs: Array) -> void:
	if suggs == null or suggs.is_empty():
		Debug.logclr("No suggestions found", Color.YELLOW)
		return
	
	header.set_suggestion_header()
	
	for sugg in suggs:
		Debug.logr(sugg)
		var suggestion: Suggestion = suggestion_scene.instantiate()
		suggestion.fill(sugg)
		suggestions_root.add_child(suggestion)
	
	var note = no_results_note.instantiate()
	add_child(note)


func _exit_tree() -> void:
	for callback in cancel_callbacks:
		if callback.is_valid(): callback.call()
	cancel_callbacks.clear()

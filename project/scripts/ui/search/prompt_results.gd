extends VBoxContainer

@export var gate_events: GateEvents
@export var api: ApiSettings
@export var result_scene: PackedScene

var result_str: String


func _ready() -> void:
	pass


func _on_search_text_changed(query: String) -> void:
	clear()
	if query.is_empty(): return
	
	await prompt_request(query)
	
	var prompts = JSON.parse_string(result_str)
	if prompts == null or prompts.is_empty():
		return
	
	for prompt in prompts:
		var result: PromptResult = result_scene.instantiate()
		result.fill(prompt)
		add_child(result)


func prompt_request(query: String) -> void:
	var url = api.prompt + query.uri_encode()
	var callback = func(_result, code, _headers, body):
		if code == 200:
			result_str = body.get_string_from_utf8()
		else: Debug.logclr("Request prompt failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback)
	if err != HTTPRequest.RESULT_SUCCESS: Debug.logclr("Cannot send request prompt", Color.RED)


func clear() -> void:
	for child in get_children():
		child.queue_free()
		remove_child(child)

extends VBoxContainer
class_name PromptResults

@export var gate_events: GateEvents
@export var api: ApiSettings
@export var result_scene: PackedScene

@export var panel: Control

var prompt_size: float
var result_str: String


func _ready() -> void:
	var prompt: Control = result_scene.instantiate()
	prompt_size = prompt.size.y
	prompt.queue_free()
	
	panel.visible = true
	clear()


func _on_search_text_changed(query: String) -> void:
	if query.is_empty(): clear(); return
	
	await prompt_request(query)
	clear()
	
	var prompts: Array = JSON.parse_string(result_str)
	if prompts == null or prompts.is_empty():
		return
	
	for prompt in prompts:
		var result: PromptResult = result_scene.instantiate()
		result.fill(prompt)
		add_child(result)
	
	change_size(prompts.size())


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
	change_size(0)


func change_size(promt_count: int) -> void:
	panel.size = Vector2(panel.size.x, promt_count * prompt_size)

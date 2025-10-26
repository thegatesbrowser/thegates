extends VBoxContainer
class_name PromptResults

@export var api: ApiSettings
@export var gate_events: GateEvents
@export var result_scene: PackedScene
@export var panel: Control

@export var request_interval_ms: int = 100

var prompt_size: float
var result_str: String
var last_query: String
var cancel_callbacks: Array[Callable] = []

var debounce_timer: Timer
var last_request_ms: int
var pending_query: String


func _ready() -> void:
	var prompt: Control = result_scene.instantiate()
	prompt_size = prompt.size.y
	prompt.queue_free()
	
	panel.visible = true
	clear()
	
	# debounce timer to prevent too many requests
	debounce_timer = Timer.new()
	debounce_timer.timeout.connect(on_debounce_timeout)
	get_parent().call_deferred("add_child", debounce_timer) # children are only PromptResults


func _on_search_text_changed(query: String) -> void:
	pending_query = query
	if query.is_empty():
		debounce_timer.stop()
		clear()
		return
	
	var now_ms: int = Time.get_ticks_msec()
	var elapsed: int = now_ms - last_request_ms
	
	if elapsed >= request_interval_ms:
		show_prompts(pending_query)
		return
	
	var remaining: float = float(request_interval_ms - elapsed) / 1000.0
	if debounce_timer.is_stopped():
		debounce_timer.start(remaining)


func on_debounce_timeout() -> void:
	debounce_timer.stop()
	show_prompts(pending_query)


func show_prompts(query: String) -> void:
	last_request_ms = Time.get_ticks_msec()
	last_query = query
	if query.is_empty(): clear(); return
	
	await prompt_request(query)
	if query != last_query: return
	clear()
	
	var result = JSON.parse_string(result_str)
	var prompts = result["prompts"]
	if prompts == null or prompts.is_empty():
		return
	
	for prompt in prompts:
		var prompt_result: PromptResult = result_scene.instantiate()
		prompt_result.fill(prompt)
		add_child(prompt_result)
	
	change_size(prompts.size())


func prompt_request(query: String) -> void:
	var url = api.prompt + query.uri_encode()
	var callback = func(_result, code, _headers, body):
		if query != last_query: return
		if code == 200:
			result_str = body.get_string_from_utf8()
		else: Debug.logclr("Request prompt failed. Code " + str(code), Color.RED)
	
	var err = await Backend.request(url, callback, {}, HTTPClient.METHOD_GET, cancel_callbacks)
	if err != OK: Debug.logclr("Cannot send request prompt", Color.RED)


func clear() -> void:
	for callback in cancel_callbacks:
		if callback.is_valid(): callback.call()
	cancel_callbacks.clear()
	
	for child in get_children():
		child.queue_free()
	change_size(0)


func change_size(promt_count: int) -> void:
	panel.size = Vector2(panel.size.x, promt_count * prompt_size)

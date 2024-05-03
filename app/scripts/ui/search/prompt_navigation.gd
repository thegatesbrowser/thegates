extends Node
class_name PromptNavigation

enum {
	UP,
	DOWN
}

@export var search: Search
@export var prompt_results: PromptResults

var current_prompt: int = -1
var actual_search_query: String


func _ready() -> void:
	search.focus_entered.connect(on_focus_entered)
	search.on_release_focus.connect(on_release_focus)
	search.on_navigation.connect(on_navigation)
	search.text_changed.connect(func(_text): reset())


func on_focus_entered() -> void:
	prompt_results._on_search_text_changed(search.text)


func on_release_focus() -> void:
	prompt_results.clear()
	reset()


func on_navigation(event: int) -> void:
	match event:
		UP:
			prompt_up()
		DOWN:
			prompt_down()
		_:
			printerr("Unhandled navigation event")


func prompt_up() -> void:
	var from: int = current_prompt
	var to: int
	
	if from == -1:
		to = prompt_results.get_children().size() - 1
	else:
		to = from - 1
	
	if from != to:
		current_prompt = to
		switch_prompt(from, to)


func prompt_down() -> void:
	var from: int = current_prompt
	var to: int
	
	if from == prompt_results.get_children().size() - 1:
		to = -1
	else:
		to = from + 1
	
	if from != to:
		current_prompt = to
		switch_prompt(from, to)


func reset() -> void:
	current_prompt = -1
	actual_search_query = ""


func switch_prompt(from: int, to: int) -> void:
	if from == -1:
		actual_search_query = search.text
	else:
		var from_prompt: PromptResult = prompt_results.get_children()[from]
		from_prompt.unfocus()
	
	if to == -1:
		search.text = actual_search_query
		search.caret_column = search.text.length()
	else:
		var to_prompt: PromptResult = prompt_results.get_children()[to]
		to_prompt.focus()
		
		search.text = to_prompt.prompt_text.text
		search.caret_column = search.text.length()

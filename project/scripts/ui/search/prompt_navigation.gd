extends Node

@export var search: Search
@export var prompt_results: PromptResults


func _ready() -> void:
	search.focus_entered.connect(_on_focus_entered)
	search.on_release_focus.connect(_on_release_focus)


func _on_focus_entered() -> void:
	prompt_results._on_search_text_changed(search.text)


func _on_release_focus() -> void:
	prompt_results.clear()

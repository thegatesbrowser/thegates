extends Node

@export var gate_events: GateEvents

@export var go_back: RoundButton
@export var go_forw: RoundButton
@export var reload: RoundButton
@export var home: RoundButton


func _ready() -> void:
	go_back.pressed.connect(Navigation.go_back)
	go_forw.pressed.connect(Navigation.go_forw)
	reload.pressed.connect(Navigation.reload)
	home.pressed.connect(Navigation.home)
	
	Navigation.updated.connect(update_buttons)
	update_buttons()


func update_buttons() -> void:
	if Navigation.can_back(): go_back.enable()
	else: go_back.disable()
	
	if Navigation.can_forw(): go_forw.enable()
	else: go_forw.disable()

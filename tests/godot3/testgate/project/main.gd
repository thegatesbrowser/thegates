extends Control

var elapsed = 0.0
var frames = 0
var last_key = "(none)"
var clicks = 0

onready var background = $Background
onready var cursor = $Cursor
onready var info = $Info


func _process(delta):
	elapsed += delta
	frames += 1

	background.color = Color(
		0.15 + 0.15 * sin(elapsed * 0.7),
		0.10 + 0.10 * sin(elapsed * 0.9 + 2.0),
		0.25 + 0.20 * sin(elapsed * 1.1 + 4.0))

	var mouse = get_global_mouse_position()
	cursor.rect_position = mouse - cursor.rect_size * 0.5
	cursor.rect_rotation = elapsed * 60.0

	info.text = "Godot %s renderer alive\nframes %d   t %.1fs\nmouse %d, %d   clicks %d\nlast key: %s" % [
		Engine.get_version_info().string, frames, elapsed, mouse.x, mouse.y, clicks, last_key]


func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		last_key = OS.get_scancode_string(event.scancode)
	if event is InputEventMouseButton and event.pressed:
		clicks += 1

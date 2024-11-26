extends TextureRect
class_name SplashScreen

@export var gate_events: GateEvents
@export var command_events: CommandEvents
@export var ui_events: UiEvents
@export var splash_screen: Texture2D

@onready var width: int = int(size.x)
@onready var height: int = int(size.y)


#func _ready():
	#gate_events.gate_info_loaded.connect(show_thumbnail)
	#gate_events.gate_entered.connect(show_splash_screen)
	#gate_events.first_frame.connect(func(): hide())
	#
	## Change size
	#show_splash_screen()


func show_thumbnail(gate: Gate, is_cached: bool) -> void:
	if is_cached: return # Resource pack is already downloaded
	
	var image: Image
	var tex = FileTools.load_external_tex(gate.image)
	
	if tex != null: image = resize_and_convert(tex.get_image(), Image.FORMAT_RGB8)
	else: image = Image.create(width, height, false, Image.FORMAT_RGB8)
	
	self.texture = ImageTexture.create_from_image(image)


func show_splash_screen() -> void:
	var image = resize_and_convert(splash_screen.get_image(), Image.FORMAT_RGBA8)
	self.texture = ImageTexture.create_from_image(image)


func resize_and_convert(image: Image, format: Image.Format) -> Image:
	image.resize(width, height)
	image.convert(format)
	#image.clear_mipmaps()
	return image

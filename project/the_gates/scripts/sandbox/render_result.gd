extends TextureRect
class_name RenderResult

@export var gate_events: GateEvents
@export var command_events: CommandEvents
@export var splash_screen: Texture2D

@onready var width = get_viewport().size.x
@onready var height = get_viewport().size.y

var rd: RenderingDevice
var ext_texure: ExternalTexture
var texture_rid: RID


func _ready() -> void:
	gate_events.gate_entered.connect(create_external_texture)
	command_events.send_filehandle.connect(send_filehandle)
	initialize()


func initialize() -> void:
	rd = RenderingServer.get_rendering_device()
	
	var image = Image.create(width, height, false, Image.FORMAT_RGB8)
	self.texture = ImageTexture.create_from_image(image)
	texture_rid = RenderingServer.texture_get_rd_texture(self.texture.get_rid())
	if not texture_rid.is_valid(): Debug.logerr("Cannot create ImageTexture")


func create_external_texture() -> void:
	var t_format: RDTextureFormat = RDTextureFormat.new()
	t_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	t_format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	t_format.width = width
	t_format.height = height
	t_format.depth = 1
	var t_view: RDTextureView = RDTextureView.new()
	
	var image = splash_screen.get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.clear_mipmaps()
	
	ext_texure = ExternalTexture.new()
	var err = ext_texure.create(t_format, t_view, [image.get_data()])
	if err: Debug.logerr("Cannot create external texture"); return
	else: Debug.logclr("External texture created", Color.AQUAMARINE)


func send_filehandle(filehandle_path: String) -> void:
	Debug.logr("Sending filehandle...")
	var sent = false
	while not sent:
		sent = ext_texure.send_filehandle(filehandle_path)
		await get_tree().create_timer(0.1).timeout
	Debug.logr("filehandle was sent")


func _process(_delta: float) -> void:
	if ext_texure == null or not ext_texure.get_rid().is_valid(): return
	if not texture_rid.is_valid(): return
	ext_texure.copy_to(texture_rid)

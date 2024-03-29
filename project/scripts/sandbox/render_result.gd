extends TextureRect
class_name RenderResult

@export var gate_events: GateEvents
@export var command_events: CommandEvents
@export var splash_screen: Texture2D

var rd: RenderingDevice
var ext_texure: ExternalTexture
var texture_rid: RID

@onready var width: int = get_viewport().size.x
@onready var height: int = get_viewport().size.y


func _ready() -> void:
	gate_events.gate_info_loaded.connect(initialize)
	gate_events.gate_entered.connect(create_external_texture)
	command_events.send_filehandle.connect(send_filehandle)
	
	# Change size
	var image = resize_and_convert(splash_screen.get_image(), Image.FORMAT_RGB8)
	self.texture = ImageTexture.create_from_image(image)


func initialize(gate: Gate, is_cached: bool) -> void:
	rd = RenderingServer.get_rendering_device()
	
	if not is_cached: # Show thumbnail image
		self.texture = create_gate_image(gate)
	
	texture_rid = RenderingServer.texture_get_rd_texture(self.texture.get_rid())
	if not texture_rid.is_valid(): Debug.logerr("Cannot create ImageTexture")


func create_gate_image(gate: Gate) -> ImageTexture:
	var tex = FileTools.load_external_tex(gate.image)
	
	var image: Image
	if tex != null: image = resize_and_convert(tex.get_image(), Image.FORMAT_RGB8)
	else: image = Image.create(width, height, false, Image.FORMAT_RGB8)
	
	return ImageTexture.create_from_image(image)


func create_external_texture() -> void:
	var t_format: RDTextureFormat = RDTextureFormat.new()
	t_format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	t_format.usage_bits = RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | \
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	t_format.width = width
	t_format.height = height
	t_format.depth = 1
	var t_view: RDTextureView = RDTextureView.new()
	
	# For some reason when switching scene something is not freed
	# So need to wait to free that up
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	ext_texure = ExternalTexture.new()
	var image = resize_and_convert(splash_screen.get_image(), Image.FORMAT_RGBA8)
	var err = ext_texure.create(t_format, t_view, [image.get_data()])
	if err: Debug.logerr("Cannot create external texture")
	else: Debug.logclr("External texture created", Color.AQUAMARINE)


func resize_and_convert(image: Image, format: Image.Format) -> Image:
	image.resize(width, height)
	image.convert(format)
	image.clear_mipmaps()
	return image


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

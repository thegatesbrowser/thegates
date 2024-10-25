extends TextureRect
class_name RenderResult

@export var gate_events: GateEvents
@export var command_events: CommandEvents
@export var ui_events: UiEvents

@onready var width: int = get_viewport().size.x
@onready var height: int = get_viewport().size.y

var ext_texure: ExternalTexture
var texture_rid: RID


func _ready() -> void:
	gate_events.gate_entered.connect(create_external_texture)
	command_events.send_filehandle.connect(send_filehandle)
	command_events.ext_texture_format.connect(set_texture_format)
	gate_events.first_frame.connect(show_render)
	
	# Create empty texture with window size
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
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
	
	# For some reason when switching scene something is not freed
	# So need to wait to free that up
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	ext_texure = ExternalTexture.new()
	var err = ext_texure.create(t_format, t_view)
	if err: Debug.logerr("Cannot create external texture")
	else: Debug.logclr("External texture created", Color.DIM_GRAY)


func send_filehandle(filehandle_path: String) -> void:
	Debug.logclr("Sending filehandle...", Color.DIM_GRAY)
	var sent = false
	while not sent:
		sent = ext_texure.send_filehandle(filehandle_path)
		await get_tree().process_frame
	Debug.logclr("filehandle was sent", Color.DIM_GRAY)


func set_texture_format(format: RenderingDevice.DataFormat) -> void:
	match format:
		RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM:
			set_param("ext_texture_is_bgra", false)
			Debug.logclr("External texture format is set to RGBA8", Color.DIM_GRAY)
		RenderingDevice.DATA_FORMAT_B8G8R8A8_UNORM:
			set_param("ext_texture_is_bgra", true)
			Debug.logclr("External texture format is set to BGRA8", Color.DIM_GRAY)
		_:
			Debug.logerr("Texture format %d is not supported" % [format])


func show_render() -> void:
	set_param("show_render", true)


func set_param(param: StringName, value: Variant) -> void:
	(material as ShaderMaterial).set_shader_parameter(param, value)


func _process(_delta: float) -> void:
	if ext_texure == null or not ext_texure.get_rid().is_valid(): return
	if not texture_rid.is_valid(): return
	
	ext_texure.copy_to(texture_rid)

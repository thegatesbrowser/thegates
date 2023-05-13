extends Node
class_name PackLoader

@export var gate_events: GateEvents
@export var render_result: TextureRect
@export var splash_screen: Texture2D

var gate: Gate
var pid: int

@onready var width = get_viewport().size.x
@onready var height = get_viewport().size.y

var rd: RenderingDevice
var ext_texure_rid: RID
var result_texture_rid: RID


func _ready() -> void:
	gate_events.gate_loaded.connect(create_process)
	initialize()


func _process(_delta: float) -> void:
	texture_update()


func initialize() -> void:
	rd = RenderingServer.get_rendering_device()
	
	var image = Image.create(width, height, false, Image.FORMAT_RGB8)
	render_result.texture = ImageTexture.create_from_image(image)
	result_texture_rid = RenderingServer.texture_get_rd_texture(render_result.texture.get_rid())
	if not result_texture_rid.is_valid(): Debug.logerr("Cannot create ImageTexture")
	else: Debug.logclr("Render result texture created", Color.AQUAMARINE)


func create_process(_gate: Gate) -> void:
	gate = _gate
	
	var sandbox_path = "/home/nordup/projects/godot/the-gates-folder/the-gates/bin/godot.linuxbsd.editor.dev.sandbox.x86_64.llvm"
	var pack_file = ProjectSettings.globalize_path(gate.resource_pack)
	var main_pid = OS.get_process_id()
	var fd = create_external_texture()
	if fd == -1: Debug.logerr("Cannot create external texture"); return
	else: Debug.logclr("External texture created " + str(fd), Color.AQUAMARINE)
	
	var args = [
		"--main-pack", pack_file,
		"--resolution", "%dx%d" % [width, height],
		"--external-image", fd,
		"--main-pid", main_pid
	]
	Debug.logclr(sandbox_path + " " + " ".join(args), Color.DARK_VIOLET)
	pid = OS.create_process(sandbox_path, args)
	
	gate_events.gate_entered_emit()


func create_external_texture() -> int:
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
	ext_texure_rid = rd.create_external_texture(t_format, t_view, [image.get_data()])
	Debug.logr("External texture rid " + str(ext_texure_rid))
	return rd.get_external_texture_fd(ext_texure_rid)


func texture_update() -> void:
	if not ext_texure_rid.is_valid() or not result_texture_rid.is_valid(): return
	
	rd.texture_copy(ext_texure_rid, result_texture_rid, Vector3.ZERO, Vector3.ZERO,
		Vector3(width, height, 1), 0, 0, 0, 0)


func kill_process() -> void:
	if OS.is_process_running(pid):
		OS.kill(pid)
		Debug.logclr("Process killed " + str(pid), Color.DIM_GRAY)

	if ext_texure_rid.is_valid():
		rd.free_rid(ext_texure_rid)
		Debug.logclr("Rd texture freed " + str(ext_texure_rid), Color.DIM_GRAY)


func _exit_tree() -> void:
	kill_process()

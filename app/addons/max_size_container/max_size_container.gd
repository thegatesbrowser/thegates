# Made by Matthieu Huvé
# Ported for Godot 4 Beta 10 by Benedikt Wicklein
# Updated for Godot 4.x by Brom Bresenham (tested on Godot 4.2-dev2)

## Limits the size of its single child node to arbitrary dimensions.
@tool
@icon("res://addons/max_size_container/icon.png")
class_name MaxSizeContainer
extends MarginContainer

# Enums
enum MODE
{
	PIXEL_SIZE,       ## Limits the child to a specific pixel size.
	ASPECT_FIT,       ## Constrains the child to a specific aspect ratio. [member limit] is used as a ratio; (4,3) is equivalent to (8,6).
	ASPECT_OR_WIDER,  ## [member limit] specifies the narrowest allowed aspect ratio.
	ASPECT_OR_TALLER  ## [member limit] specifies the shortest allowed aspect ratio.
}

enum {LEFT, RIGHT, TOP, BOTTOM}

enum VERTICAL_ALIGN
{
	TOP,    ## Align with the top side of this MaxSizeContainer.
	CENTER, ## Center vertically within this MaxSizeContainer.
	BOTTOM  ## Align with the bottom side of this MaxSizeContainer.
}

enum HORIZONTAL_ALIGN
{
	LEFT,   ## Align with the left side of this MaxSizeContainer.
	CENTER, ## Center horizontally within this MaxSizeContainer.
	RIGHT   ## Align with the right side of this MaxSizeContainer.
}

# Parameters
## The constraint mode of this container.
@export var mode := MODE.PIXEL_SIZE:
	set(value):
		if value == mode: return
		mode = value

		if value == MODE.PIXEL_SIZE:
			limit = pixel_limit
		else:
			limit = aspect_limit

## In Pixel Size mode, the maximum size the child node is allowed to be, or '-1' for no limit. In other modes, an aspect ratio, where (4,3) is equivalent to (8,6), and so on.
@export var limit := Vector2(-1, -1):
	set(value):
		if mode == MODE.PIXEL_SIZE:
			if value.x < 0: value.x = -1
			if value.y < 0: value.y = -1

			limit = value
			pixel_limit = value
			max_size = value

		else:
			if value.x <= 0:  value.x = 1
			if value.y <= 0:  value.y = 1
			limit = value
			aspect_limit = value

		if is_initialized:
			_adapt_margins()

## How the child node is vertically aligned within the excess space once it has reached its maximum height.
@export var valign := VERTICAL_ALIGN.CENTER:
	set(value):
		valign = value
		if is_initialized:
			_adapt_margins()

## How the child node is horizontally aligned within the excess space once it has reached its maximum width.
@export var halign := HORIZONTAL_ALIGN.CENTER:
	set(value):
		halign = value

		if is_initialized:
			_adapt_margins()

var max_size     := Vector2(-1,-1)
var pixel_limit  := Vector2(-1,-1)
var aspect_limit := Vector2(1,1)

# child node of the container
var child : Node

# Intern var
var minimum_child_size : Vector2
var is_size_valid := {"x": false, "y": false}
var is_initialized := false

var is_resizing := false # infinite recursion guard

func _ready() -> void:
	# Reset custom margins if modified from the editor
	_set_custom_margin(LEFT, 0)
	_set_custom_margin(RIGHT, 0)
	_set_custom_margin(TOP, 0)
	_set_custom_margin(BOTTOM, 0)

	# Sets up the Container
	resized.connect(_on_self_resized)

	child_entered_tree.connect( _on_child_entered_tree )
	child_exiting_tree.connect( _on_child_exiting_tree )

	if get_child_count() > 0:
		_initialize(get_child(0))

func _initialize(p_child: Node) -> void:
	# Sets the child node
	if not p_child: return
	child = p_child
	minimum_child_size = p_child.get_combined_minimum_size()
	p_child.minimum_size_changed.connect( _on_child_minimum_size_changed )

	_adapt_margins()

	# Tells other parts that the child node is ready
	# important to avoid early calculations that give wrong minimum child size
	is_initialized = true

func _update_maximum_size():
	if mode != MODE.PIXEL_SIZE:
		var fit_w = size.y * (aspect_limit.x / aspect_limit.y)  # aspect pixel width given current height
		var fit_h = size.x * (aspect_limit.y / aspect_limit.x)  # aspect pixel height given current width

		match mode:
			MODE.ASPECT_FIT:
				if fit_w <= size.x:
					max_size.x = fit_w
					max_size.y = size.y
				else:
					max_size.x = size.x
					max_size.y = fit_h

			MODE.ASPECT_OR_WIDER:
				if fit_w <= size.x:
					max_size.x = -1
					max_size.y = size.y
				else:
					max_size.x = -1
					max_size.y = fit_h

			MODE.ASPECT_OR_TALLER:
				if fit_w <= size.x:
					max_size.x = fit_w
					max_size.y = -1
				else:
					max_size.x = size.x
					max_size.y = -1

	_validate_maximum_size()


func _validate_maximum_size() -> void:
	# This function checks if the child is smaller than max_size.
	# Otherwise there would be a risk of infinite margins
	if child == null:
		return

	if max_size.x < 0:
		is_size_valid.x = false
	elif minimum_child_size.x > max_size.x:
		is_size_valid.x = false
		push_warning(str("max_size ( ", max_size, " ) ignored on x axis: too small.",
				"The minimum possible size is: ", minimum_child_size))
	else:
		is_size_valid.x = true

	if max_size.y < 0:
		is_size_valid.y = false
	elif minimum_child_size.y > max_size.y:
		is_size_valid.y = false
		push_warning(str("max_size ( ", max_size, " ) ignored on y axis: too small.",
				"The minimum possible size is: ", minimum_child_size))
	else:
		is_size_valid.y = true


func _adapt_margins() -> void:
	# Adapts the margin to keep the child size below max_size
	_update_maximum_size()  # adjusts & validates max size for aspect modes

	var rect_size := size
	# If the container size is smaller than the max size, no margins are necessary
	if rect_size.x < max_size.x:
		_set_custom_margin(LEFT, 0)
		_set_custom_margin(RIGHT, 0)
	if rect_size.y < max_size.y:
		_set_custom_margin(TOP, 0)
		_set_custom_margin(BOTTOM, 0)

	### x ###
	# If the max_size is smaller than the child's size: ignore it
	if not is_size_valid.x:
		_set_custom_margin(LEFT, 0)
		_set_custom_margin(RIGHT, 0)

	# Else, adds margins to keep the child's rect_size below the max_size
	elif rect_size.x >= max_size.x:
		var new_margin_left : int
		var new_margin_right : int

		match halign:
			HORIZONTAL_ALIGN.LEFT:
				new_margin_left = 0
				new_margin_right = int(rect_size.x - max_size.x)
			HORIZONTAL_ALIGN.CENTER:
				new_margin_left = int((rect_size.x - max_size.x) / 2)
				new_margin_right = int((rect_size.x - max_size.x) / 2)
			HORIZONTAL_ALIGN.RIGHT:
				new_margin_left = int(rect_size.x - max_size.x)
				new_margin_right = 0

		_set_custom_margin(LEFT, new_margin_left)
		_set_custom_margin(RIGHT, new_margin_right)

	### y ###
	# If the max_size is smaller than the child's size: ignore it
	if not is_size_valid.y:
		_set_custom_margin(TOP, 0)
		_set_custom_margin(BOTTOM, 0)

	# Else, adds margins to keep the child's rect_size below the max_size
	elif rect_size.y >= max_size.y:
		var new_margin_top : int
		var new_margin_bottom : int

		match valign:
			VERTICAL_ALIGN.TOP:
				new_margin_top = 0
				new_margin_bottom = int(rect_size.y - max_size.y)
			VERTICAL_ALIGN.CENTER:
				new_margin_top = int((rect_size.y - max_size.y) / 2)
				new_margin_bottom = int((rect_size.y - max_size.y) / 2)
			VERTICAL_ALIGN.BOTTOM:
				new_margin_top = int(rect_size.y - max_size.y)
				new_margin_bottom = 0

		_set_custom_margin(TOP, new_margin_top)
		_set_custom_margin(BOTTOM, new_margin_bottom)


func _set_custom_margin(side : int, value : int) -> void:
# This function makes custom constants modifications easier
	match side:
		LEFT:   add_theme_constant_override("margin_left", value)
		RIGHT:  add_theme_constant_override("margin_right", value)
		TOP:    add_theme_constant_override("margin_top", value)
		BOTTOM: add_theme_constant_override("margin_bottom", value)


func _on_self_resized() -> void:
	# To avoid errors in tool mode and setup, the container must be fully ready
	if is_initialized and not is_resizing:
		is_resizing = true
		_adapt_margins()
		is_resizing = false


func _on_child_entered_tree( p_child:Node ) -> void:
	if get_child_count() == 1:
		_initialize( p_child )
	else:
		push_warning(str("MaxSizeContainer can only handle one child. ", p_child.name,
		" will be ignored because ", get_child(0).name, " is the first child."))

func _on_child_exiting_tree( p_child:Node ) -> void:
	if not p_child == child:
		# Some other child that we're not paying attention to is being removed
		return

	# Stops margin calculations
	is_initialized = false

	# Disconnect signals
	p_child.minimum_size_changed.disconnect( _on_child_minimum_size_changed )
	child = null

	# Reset custom margins
	_set_custom_margin(LEFT, 0)
	_set_custom_margin(RIGHT, 0)
	_set_custom_margin(TOP, 0)
	_set_custom_margin(BOTTOM, 0)

	if get_child_count() > 1:
		# There will still be at least one node remaining. Reinitialize and manage it.
		for i in range( get_child_count() ):
			var cur = get_child(i)
			if cur != p_child:
				_initialize( cur )
				break


func _on_child_minimum_size_changed() -> void:
	minimum_child_size = child.get_combined_minimum_size()
	_validate_maximum_size()

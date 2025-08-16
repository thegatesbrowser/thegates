extends Control
class_name BookmarkJumpAnimation

var base_position: Vector2
var base_z_index: int
var tween: Tween


func start_jump_animation() -> void:
	base_position = position
	base_z_index = z_index
	z_index = 1
	
	var up_position: Vector2 = base_position + Vector2(0, -6)
	var down_position: Vector2 = base_position + Vector2(0, 6)
	
	if is_instance_valid(tween): tween.stop()
	tween = create_tween()
	tween.set_loops()
	
	tween.tween_interval(1.0)
	tween.tween_property(self, "position", down_position, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", up_position, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", base_position, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func stop_jump_animation() -> void:
	if is_instance_valid(tween): tween.stop()
	position = base_position
	z_index = base_z_index


func _exit_tree() -> void:
	stop_jump_animation()

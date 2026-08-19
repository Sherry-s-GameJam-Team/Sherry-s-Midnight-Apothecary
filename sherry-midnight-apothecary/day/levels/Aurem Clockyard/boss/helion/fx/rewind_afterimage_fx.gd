extends Node2D
class_name HelionRewindAfterimage

var target_pos: Vector2 = Vector2.ZERO
var is_active: bool = false
var distortion_active: bool = false

func _ready():
	modulate = Color(0.4, 0.6, 1.0, 0.5)
	visible = false

func show_target(new_target_position: Vector2):
	target_pos = new_target_position
	global_position = target_pos
	is_active = true
	visible = true
	modulate = Color(0.4, 0.6, 1.0, 0.5)
	queue_redraw()

func update_target(new_target_position: Vector2):
	target_pos = new_target_position
	global_position = target_pos

func highlight_and_commit():
	if not is_active:
		return
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(0.8, 0.9, 1.0, 1.0), 0.05)
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(hide_target)

func hide_target():
	is_active = false
	visible = false

func begin_distortion():
	distortion_active = true
	queue_redraw()
	
	var tween = create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2)

func end_distortion():
	distortion_active = false
	scale = Vector2.ONE
	queue_redraw()

func _draw():
	if is_active:
		draw_circle(Vector2.ZERO, 40, Color(1, 1, 1, 1))
	
	if distortion_active:
		draw_arc(Vector2.ZERO, 50, 0, TAU, 16, Color(0.4, 0.6, 1.0, 0.8), 5.0)

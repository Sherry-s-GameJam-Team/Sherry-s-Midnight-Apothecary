class_name BloodLeafTelegraph
extends Node2D

@export var radius: float = 60.0
@export var base_color: Color = Color(0.9, 0.2, 0.2, 0.4)

var _progress: float = 0.0
var _spin_angle: float = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_spin_angle += delta * 2.8
	queue_redraw()


func set_progress(val: float) -> void:
	_progress = clampf(val, 0.0, 1.0)
	queue_redraw()


func reset() -> void:
	_progress = 0.0
	_spin_angle = 0.0
	queue_redraw()


func _draw() -> void:
	var pulse := 0.6 + 0.4 * sin(_spin_angle * 3.2)
	var fill_color := Color(base_color.r, base_color.g, base_color.b, base_color.a * _progress * pulse * 0.45)
	var ring_color := Color(base_color.r, base_color.g, base_color.b, base_color.a * pulse)

	# Inner growing danger fill
	draw_circle(Vector2.ZERO, radius * (0.2 + 0.8 * _progress), fill_color)

	# Outer rotating segmented ring
	var segments := 6
	var segment_angle := TAU / float(segments)
	var arc_len := segment_angle * 0.65
	for i in range(segments):
		var start_a := _spin_angle + float(i) * segment_angle
		var end_a := start_a + arc_len
		draw_arc(Vector2.ZERO, radius, start_a, end_a, 8, ring_color, 2.0)

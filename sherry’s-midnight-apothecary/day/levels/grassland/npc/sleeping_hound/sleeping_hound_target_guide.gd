class_name SleepingHoundTargetGuide
extends Node2D

@export var target_offset := Vector2(0.0, -72.0)
@export_range(40.0, 260.0, 1.0) var target_radius := 135.0
@export var guide_color := Color(1.0, 0.82, 0.18, 0.95)

var _elapsed := 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var pulse := (sin(_elapsed * 5.5) + 1.0) * 0.5
	var radius := target_radius + pulse * 8.0
	var color := Color(guide_color, 0.62 + pulse * 0.3)
	draw_arc(target_offset, radius, 0.0, TAU, 64, color, 5.0, true)
	draw_arc(target_offset, radius - 10.0, 0.0, TAU, 64, Color(color, 0.28), 2.0, true)

	var tip := target_offset + Vector2(0.0, -radius - 12.0)
	var top := tip + Vector2(0.0, -72.0 - pulse * 10.0)
	draw_line(top, tip, color, 14.0, true)
	var arrow := PackedVector2Array([
		tip,
		tip + Vector2(-28.0, -30.0),
		tip + Vector2(28.0, -30.0),
	])
	draw_colored_polygon(arrow, color)


func show_target(offset: Vector2, radius: float) -> void:
	target_offset = offset
	target_radius = radius
	_elapsed = 0.0
	show()
	queue_redraw()


func hide_target() -> void:
	hide()

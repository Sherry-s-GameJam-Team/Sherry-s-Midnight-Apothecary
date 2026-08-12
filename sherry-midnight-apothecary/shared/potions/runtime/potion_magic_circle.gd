class_name PotionMagicCircle
extends Node2D

var circle_color := Color(0.55, 0.82, 1.0, 0.0)
var _active := false


func _ready() -> void:
	visible = false
	queue_redraw()


func show_circle(color: Color) -> void:
	circle_color = color
	circle_color.a = 0.9
	_active = true
	visible = true
	modulate.a = 0.0
	var tween := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	tween.tween_property(self, "rotation", rotation + PI * 0.35, 0.5)
	queue_redraw()


func hide_circle() -> void:
	_active = false
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func() -> void: visible = false)


func _process(delta: float) -> void:
	if _active:
		rotation += delta * 1.8


func _draw() -> void:
	for radius in [26.0, 36.0, 43.0]:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, circle_color, 2.0, true)
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var inner := Vector2.from_angle(angle) * 28.0
		var outer := Vector2.from_angle(angle + 0.32) * 41.0
		draw_line(inner, outer, circle_color, 2.0, true)


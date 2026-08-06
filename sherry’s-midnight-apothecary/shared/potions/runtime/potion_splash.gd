class_name PotionSplash
extends Node2D

var splash_color := Color.WHITE


func setup(color: Color) -> void:
	splash_color = color
	queue_redraw()
	var tween := create_tween().set_ignore_time_scale(true).set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.7, 0.28).from(Vector2.ONE * 0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.42).from(1.0)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 22.0, Color(splash_color, 0.55))
	for index in range(12):
		var direction := Vector2.from_angle(TAU * float(index) / 12.0)
		draw_line(direction * 18.0, direction * (34.0 + float(index % 3) * 7.0), splash_color, 4.0, true)


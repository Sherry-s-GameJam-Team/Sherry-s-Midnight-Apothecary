class_name MenuStarField
extends Node2D

@export_range(0, 256, 1) var amount := 72:
	set(value):
		amount = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var opacity := 0.35:
	set(value):
		opacity = value
		queue_redraw()


func _draw() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 0x5A31
	for _index in range(amount):
		var point := Vector2(random.randf_range(-1200.0, 1200.0), random.randf_range(30.0, 650.0))
		var radius := random.randf_range(0.7, 1.8)
		draw_circle(point, radius, Color(0.96, 0.91, 1.0, opacity * random.randf_range(0.45, 1.0)))

class_name MenuMoon
extends Node2D

@export var moon_texture: Texture2D:
	set(value):
		moon_texture = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var opacity := 0.7:
	set(value):
		opacity = value
		queue_redraw()
@export var shade_color := Color("171536"):
	set(value):
		shade_color = value
		queue_redraw()


func _draw() -> void:
	if moon_texture != null:
		draw_texture_rect(moon_texture, Rect2(-64, -64, 128, 128), false, Color(1, 1, 1, opacity))
		return
	draw_circle(Vector2.ZERO, 56.0, Color(1.0, 0.93, 0.72, opacity))
	draw_circle(Vector2(23.0, -10.0), 49.0, Color(shade_color, opacity))

class_name MenuCloudLayer
extends Node2D

@export var cloud_texture: Texture2D:
	set(value):
		cloud_texture = value
		queue_redraw()
@export var opacity := 0.2:
	set(value):
		opacity = value
		queue_redraw()
@export var drift_speed := 2.0
@export var cloud_scale := 1.0

var _drift := 0.0


func _process(delta: float) -> void:
	_drift = fposmod(_drift + drift_speed * delta, 640.0)
	queue_redraw()


func _draw() -> void:
	var tint := Color(0.94, 0.92, 1.0, opacity)
	for repeat_index in range(-1, 5):
		var origin := Vector2(float(repeat_index) * 640.0 + _drift - 960.0, 0.0)
		if cloud_texture != null:
			draw_texture_rect(cloud_texture, Rect2(origin, Vector2(620.0, 180.0) * cloud_scale), false, tint)
		else:
			_draw_placeholder_cloud(origin, tint)


func _draw_placeholder_cloud(origin: Vector2, tint: Color) -> void:
	var points := PackedVector2Array([origin + Vector2(0, 132) * cloud_scale])
	for sample_index in range(31):
		var x := float(sample_index) * 20.0
		var broad_curve := sin(PI * x / 600.0)
		var small_lobes := pow(absf(sin(PI * x / 185.0)), 1.7)
		var y := 112.0 - broad_curve * 30.0 - small_lobes * 23.0
		points.append(origin + Vector2(x, y) * cloud_scale)
	points.append(origin + Vector2(600, 132) * cloud_scale)
	draw_colored_polygon(points, tint)

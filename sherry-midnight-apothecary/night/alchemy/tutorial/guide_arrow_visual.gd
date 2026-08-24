class_name GuideArrowVisual
extends Control

@export var color := Color(1.0, 0.88, 0.28, 0.95)
@export var glow_color := Color(0.95, 0.55, 0.1, 0.45)
@export var stroke_color := Color(0.35, 0.15, 0.05, 0.9)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	# Stylized arrow pointing downward with apex at (0, 0)
	var arrow_poly: PackedVector2Array = [
		Vector2(0, 0),        # Tip
		Vector2(-20, -32),    # Left head corner
		Vector2(-8, -28),     # Left shaft junction
		Vector2(-8, -52),     # Left shaft top
		Vector2(8, -52),      # Right shaft top
		Vector2(8, -28),      # Right shaft junction
		Vector2(20, -32),     # Right head corner
	]

	# Outer glow
	var glow_poly := arrow_poly.duplicate()
	for i in range(glow_poly.size()):
		glow_poly[i] *= 1.25
	draw_colored_polygon(glow_poly, glow_color)

	# Main body
	draw_colored_polygon(arrow_poly, color)

	# Dark outline stroke
	draw_polyline(arrow_poly, stroke_color, 2.5, true)
	# Connect last point to first
	draw_line(arrow_poly[-1], arrow_poly[0], stroke_color, 2.5, true)

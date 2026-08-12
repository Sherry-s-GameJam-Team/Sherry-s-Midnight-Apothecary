@tool
class_name TemperatureRangeOverlay
extends Control

@export_group("Editor Preview Temperature Bands")
@export_range(0.0, 100.0, 0.1) var preview_warning_min := 35.0:
	set(value):
		preview_warning_min = value
		queue_redraw()
@export_range(0.0, 100.0, 0.1) var preview_ideal_min := 45.0:
	set(value):
		preview_ideal_min = value
		queue_redraw()
@export_range(0.0, 100.0, 0.1) var preview_ideal_max := 65.0:
	set(value):
		preview_ideal_max = value
		queue_redraw()
@export_range(0.0, 100.0, 0.1) var preview_warning_max := 75.0:
	set(value):
		preview_warning_max = value
		queue_redraw()
@export_range(0.0, 100.0, 0.1) var preview_burn_temperature := 85.0:
	set(value):
		preview_burn_temperature = value
		queue_redraw()

@export_group("Dial Geometry")
@export_range(-180.0, 0.0, 1.0) var minimum_angle := -80.0:
	set(value):
		minimum_angle = value
		queue_redraw()
@export_range(0.0, 180.0, 1.0) var maximum_angle := 80.0:
	set(value):
		maximum_angle = value
		queue_redraw()
@export_range(0.1, 0.5, 0.01) var tick_radius_ratio := 0.37:
	set(value):
		tick_radius_ratio = value
		queue_redraw()
@export_range(0.0, 0.2, 0.005) var range_gap_ratio := 0.075:
	set(value):
		range_gap_ratio = value
		queue_redraw()
@export_range(0.01, 0.15, 0.005) var range_width_ratio := 0.035:
	set(value):
		range_width_ratio = value
		queue_redraw()

var _profile: HeatProfileData


func set_heat_profile(next_profile: HeatProfileData) -> void:
	_profile = next_profile
	queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * tick_radius_ratio
	_draw_temperature_ticks(center, radius)
	var warning_min := _profile.warning_min if _profile != null else preview_warning_min
	var warning_max := _profile.warning_max if _profile != null else preview_warning_max
	var ideal_min := _profile.ideal_min if _profile != null else preview_ideal_min
	var ideal_max := _profile.ideal_max if _profile != null else preview_ideal_max
	var burn_temperature := _profile.burn_temperature if _profile != null else preview_burn_temperature
	var range_gap := maxf(radius * range_gap_ratio, 3.0)
	var range_width := maxf(radius * range_width_ratio, 2.0)
	_draw_range_arc(center, radius - range_gap, warning_min, warning_max, Color("#bc8433"), range_width)
	_draw_range_arc(center, radius - range_gap * 2.0, ideal_min, ideal_max, Color("#478c4d"), range_width + 1.0)
	_draw_range_arc(center, radius - range_gap * 3.0, burn_temperature, 100.0, Color("#aa3a31"), range_width)


func _draw_temperature_ticks(center: Vector2, radius: float) -> void:
	for tick in range(11):
		var ratio := float(tick) / 10.0
		var angle := deg_to_rad(lerpf(minimum_angle, maximum_angle, ratio) - 90.0)
		var direction := Vector2(cos(angle), sin(angle))
		var major := tick % 2 == 0
		var outer := center + direction * radius
		var tick_length := radius * (0.15 if major else 0.09)
		var inner := center + direction * (radius - tick_length)
		draw_line(inner, outer, Color(0.24, 0.13, 0.05, 0.88), 2.0 if major else 1.0, true)


func _draw_range_arc(center: Vector2, radius: float, minimum: float, maximum: float, color: Color, width: float) -> void:
	var from_angle := deg_to_rad(lerpf(minimum_angle, maximum_angle, minimum / 100.0) - 90.0)
	var to_angle := deg_to_rad(lerpf(minimum_angle, maximum_angle, maximum / 100.0) - 90.0)
	draw_arc(center, radius, from_angle, to_angle, 28, color, width, true)

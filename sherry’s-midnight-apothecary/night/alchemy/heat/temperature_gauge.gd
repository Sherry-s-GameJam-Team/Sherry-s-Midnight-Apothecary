class_name TemperatureGauge
extends Control

@export_range(-180.0, 0.0, 1.0) var minimum_needle_angle := -80.0
@export_range(0.0, 180.0, 1.0) var maximum_needle_angle := 80.0
@export_range(0.0, 1.0, 0.01) var needle_smoothing := 0.16

@onready var needle: TextureRect = $TemperatureNeedle
@onready var wheel_background: TextureRect = $WheelBackground
@onready var value_label: Label = $TemperatureValue
@onready var fire_label: Label = get_node_or_null("FirePowerLabel")
@onready var time_label: Label = get_node_or_null("BrewTimeLabel")
@onready var status_label: Label = get_node_or_null("HeatStatusLabel")

var temperature := 20.0
var fire_power := 0.0
var profile: HeatProfileData
var brew_elapsed := 0.0
var brew_duration := 0.0
var hold_ratio := 0.0
var _target_rotation := 0.0
var _last_dial_rect := Rect2()


func _ready() -> void:
	resized.connect(_update_dial_layout)
	if wheel_background != null:
		wheel_background.resized.connect(_update_dial_layout)
	call_deferred("_update_dial_layout")


func set_heat_state(next_temperature: float, next_fire_power: float, next_profile: HeatProfileData, elapsed: float, duration: float, ideal_ratio: float) -> void:
	temperature = clampf(next_temperature, 0.0, 100.0)
	fire_power = clampf(next_fire_power, 0.0, 1.0)
	profile = next_profile
	brew_elapsed = maxf(elapsed, 0.0)
	brew_duration = maxf(duration, 0.0)
	hold_ratio = clampf(ideal_ratio, 0.0, 1.0)
	_target_rotation = deg_to_rad(lerpf(minimum_needle_angle, maximum_needle_angle, temperature / 100.0))
	if value_label != null:
		value_label.text = "%d °C" % roundi(temperature)
	if fire_label != null:
		fire_label.text = "火势 %d%%" % roundi(fire_power * 100.0)
	if time_label != null:
		time_label.text = "%0.1f / %0.1fs" % [brew_elapsed, brew_duration]
	if status_label != null:
		status_label.text = _status_text()
		status_label.modulate = _status_color()
	queue_redraw()


func _process(delta: float) -> void:
	var dial_rect := _dial_rect()
	if dial_rect != _last_dial_rect:
		_update_dial_layout()
	if needle != null:
		needle.rotation = lerp_angle(needle.rotation, _target_rotation, clampf(delta / maxf(needle_smoothing, 0.001), 0.0, 1.0))


func needle_angle_degrees() -> float:
	return rad_to_deg(_target_rotation)


func _draw() -> void:
	var dial_rect := _dial_rect()
	if dial_rect.size.x <= 0.0 or dial_rect.size.y <= 0.0:
		return
	var center := dial_rect.get_center()
	var radius := minf(dial_rect.size.x, dial_rect.size.y) * 0.37
	_draw_temperature_ticks(center, radius)
	var warning_min := profile.warning_min if profile != null else 35.0
	var warning_max := profile.warning_max if profile != null else 75.0
	var ideal_min := profile.ideal_min if profile != null else 45.0
	var ideal_max := profile.ideal_max if profile != null else 65.0
	var burn_temperature := profile.burn_temperature if profile != null else 85.0
	var range_gap := maxf(radius * 0.075, 3.0)
	var range_width := maxf(radius * 0.035, 2.0)
	_draw_range_arc(center, radius - range_gap, warning_min, warning_max, Color("#bc8433"), range_width)
	_draw_range_arc(center, radius - range_gap * 2.0, ideal_min, ideal_max, Color("#478c4d"), range_width + 1.0)
	_draw_range_arc(center, radius - range_gap * 3.0, burn_temperature, 100.0, Color("#aa3a31"), range_width)
	var fire_width := maxf(radius * 1.10, 1.0)
	var fire_rect := Rect2(center.x - fire_width * 0.5, dial_rect.position.y + dial_rect.size.y * 0.82, fire_width, 3.0)
	draw_rect(fire_rect, Color(0.20, 0.11, 0.04, 0.45))
	draw_rect(Rect2(fire_rect.position, Vector2(fire_rect.size.x * fire_power, fire_rect.size.y)), Color("#c85124"))


func _dial_rect() -> Rect2:
	if wheel_background != null:
		return wheel_background.get_rect()
	return Rect2(Vector2.ZERO, size)


func _update_dial_layout() -> void:
	var dial_rect := _dial_rect()
	_last_dial_rect = dial_rect
	if needle == null or dial_rect.size.x <= 0.0 or dial_rect.size.y <= 0.0:
		queue_redraw()
		return
	var radius := minf(dial_rect.size.x, dial_rect.size.y) * 0.5
	var needle_size := Vector2(maxf(radius * 0.15, 6.0), maxf(radius * 1.12, 28.0))
	needle.size = needle_size
	needle.pivot_offset = Vector2(needle_size.x * 0.5, needle_size.y * 0.90)
	needle.position = dial_rect.get_center() - needle.pivot_offset
	queue_redraw()


func _draw_temperature_ticks(center: Vector2, radius: float) -> void:
	for tick in range(11):
		var ratio := float(tick) / 10.0
		var angle := deg_to_rad(lerpf(minimum_needle_angle, maximum_needle_angle, ratio) - 90.0)
		var direction := Vector2(cos(angle), sin(angle))
		var major := tick % 2 == 0
		var outer := center + direction * radius
		var tick_length := radius * (0.15 if major else 0.09)
		var inner := center + direction * (radius - tick_length)
		draw_line(inner, outer, Color(0.24, 0.13, 0.05, 0.88), 2.0 if major else 1.0, true)


func _draw_range_arc(center: Vector2, radius: float, minimum: float, maximum: float, color: Color, width: float) -> void:
	var from_angle := deg_to_rad(lerpf(minimum_needle_angle, maximum_needle_angle, minimum / 100.0) - 90.0)
	var to_angle := deg_to_rad(lerpf(minimum_needle_angle, maximum_needle_angle, maximum / 100.0) - 90.0)
	draw_arc(center, radius, from_angle, to_angle, 28, color, width, true)


func _status_text() -> String:
	if profile == null:
		return "等待炼制"
	if temperature < profile.warning_min:
		return "火候不足"
	if temperature < profile.ideal_min:
		return "正在升温"
	if temperature <= profile.ideal_max:
		return "温度稳定"
	if temperature <= profile.warning_max:
		return "温度偏高"
	if temperature < profile.burn_temperature:
		return "即将过热"
	return "药液正在烧焦"


func _status_color() -> Color:
	if profile == null:
		return Color("#d7b878")
	if temperature >= profile.burn_temperature:
		return Color("#df5846")
	if temperature > profile.ideal_max:
		return Color("#e7bb4b")
	if temperature >= profile.ideal_min:
		return Color("#6abe72")
	return Color("#d7b878")

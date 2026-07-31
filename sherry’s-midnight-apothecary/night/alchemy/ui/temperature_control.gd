class_name AlchemyTemperatureControl
extends Control

signal temperature_requested(value: float)

@export_group("Temperature")
@export_range(0.0, 100.0, 0.1) var temperature := 55.0
@export_range(0.1, 20.0, 0.1) var bellows_heat := 5.0
@export_range(0.0, 5.0, 0.05) var cooling_rate := 0.35
@export_range(0.0, 100.0, 0.5) var ambient_temperature := 20.0

@export_group("Gauge")
@export_range(-180.0, 0.0, 1.0) var minimum_needle_angle := -130.0
@export_range(0.0, 180.0, 1.0) var maximum_needle_angle := 130.0

@onready var needle: TextureRect = $TemperatureNeedle
@onready var value_label: Label = $TemperatureValue

var _cooling_accumulator := 0.0
var _feedback_tween: Tween


func _ready() -> void:
	set_temperature(temperature)
	call_deferred("_update_feedback_pivot")


func _process(delta: float) -> void:
	if temperature <= ambient_temperature or cooling_rate <= 0.0:
		_cooling_accumulator = 0.0
		return
	_cooling_accumulator += delta
	if _cooling_accumulator < 0.10:
		return
	var next_temperature := maxf(
		temperature - cooling_rate * _cooling_accumulator,
		ambient_temperature,
	)
	_cooling_accumulator = 0.0
	_request_temperature(next_temperature)


func set_temperature(value: float) -> void:
	temperature = clampf(value, 0.0, 100.0)
	var normalized := temperature / 100.0
	if needle != null:
		needle.rotation = deg_to_rad(lerpf(minimum_needle_angle, maximum_needle_angle, normalized))
	if value_label != null:
		value_label.text = "%d °C" % roundi(temperature)


func pump() -> void:
	_request_temperature(minf(temperature + bellows_heat, 100.0))
	_play_bellows_feedback()


func needle_angle_degrees() -> float:
	return rad_to_deg(needle.rotation) if needle != null else 0.0


func _request_temperature(value: float) -> void:
	var clamped := clampf(value, 0.0, 100.0)
	set_temperature(clamped)
	temperature_requested.emit(clamped)


func _update_feedback_pivot() -> void:
	if value_label != null:
		value_label.pivot_offset = value_label.size * 0.5


func _play_bellows_feedback() -> void:
	if value_label == null:
		return
	if _feedback_tween != null and _feedback_tween.is_running():
		_feedback_tween.kill()
	value_label.scale = Vector2(1.0, 0.78)
	_feedback_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(value_label, "scale", Vector2.ONE, 0.18)

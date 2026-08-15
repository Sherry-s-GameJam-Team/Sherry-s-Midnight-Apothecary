class_name ForestSprayDevice
extends Node2D

signal pressure_changed(current: float, maximum: float)
signal sprayed

@export var max_pressure := 100.0
@export var shot_cost := 35.0
@export var regen_per_second := 15.0
@export var cooldown := 1.2

var pressure := 100.0
var _cooldown_left := 0.0

@onready var ray: RayCast2D = $RayCast2D
@onready var spray_line: Line2D = $SprayLine

func _ready() -> void:
	pressure = max_pressure
	spray_line.visible = false
	pressure_changed.emit(pressure, max_pressure)

func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if pressure < max_pressure:
		pressure = minf(max_pressure, pressure + regen_per_second * delta)
		pressure_changed.emit(pressure, max_pressure)

func can_spray() -> bool:
	return pressure >= shot_cost and _cooldown_left <= 0.0

func spray() -> bool:
	if not can_spray():
		return false
	pressure -= shot_cost
	_cooldown_left = cooldown
	pressure_changed.emit(pressure, max_pressure)
	sprayed.emit()
	ray.force_raycast_update()
	if ray.is_colliding():
		var target := ray.get_collider()
		if target != null and target.has_method("purify"):
			target.call("purify")
	_show_spray_flash()
	return true

func cooldown_remaining() -> float:
	return _cooldown_left

func _show_spray_flash() -> void:
	spray_line.visible = true
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_callback(func(): spray_line.visible = false)

extends StaticBody2D

## Subtle horizontal drift for Golden Cliff's fixed floor sections.
@export_range(0.0, 20.0, 0.5) var sway_amplitude := 5.0
@export_range(0.05, 2.0, 0.05) var sway_speed := 0.45
@export var sway_phase := 0.0

var _origin := Vector2.ZERO

func _ready() -> void:
	_origin = position

func _physics_process(_delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	position.x = _origin.x + sin(time * sway_speed + sway_phase) * sway_amplitude

func get_sway_offset() -> float:
	return position.x - _origin.x

class_name VillageBoatBob
extends Sprite2D

## Applies a gentle lake swell without replacing the transform authored in the
## village editor. The saved boat keeps its own start position and rotation.

@export_range(0.0, 32.0, 0.1) var vertical_amplitude := 9.0
@export_range(0.0, 8.0, 0.1) var roll_degrees := 2.2
@export_range(0.1, 4.0, 0.05) var swell_cycles_per_second := 0.42

var _base_position := Vector2.ZERO
var _base_rotation := 0.0
var _elapsed := 0.0


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	var swell := sin(_elapsed * TAU * swell_cycles_per_second)
	var roll := sin(_elapsed * TAU * swell_cycles_per_second + 0.8)
	position = _base_position + Vector2(0.0, swell * vertical_amplitude)
	rotation = _base_rotation + deg_to_rad(roll * roll_degrees)

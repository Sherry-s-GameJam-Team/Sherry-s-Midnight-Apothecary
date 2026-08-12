@tool
class_name LakeWaterSurface
extends Sprite2D

@export_range(0.0, 30.0, 0.5) var bob_amplitude := 5.0
@export_range(0.1, 30.0, 0.1) var bob_period := 5.0
@export var phase_offset := 0.0

var _origin_position := Vector2.ZERO


func _ready() -> void:
	_origin_position = position
	set_process(not Engine.is_editor_hint())


func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() * 0.001
	var bob := sin(TAU * time / maxf(bob_period, 0.1) + phase_offset) * bob_amplitude
	# The two texture planes use different local periods to create time parallax.
	# They never consume Camera2D movement, so the physical water_y stays fixed
	# and travelling to the lakebed cannot drag the surface artwork down.
	position = _origin_position + Vector2(0.0, bob)

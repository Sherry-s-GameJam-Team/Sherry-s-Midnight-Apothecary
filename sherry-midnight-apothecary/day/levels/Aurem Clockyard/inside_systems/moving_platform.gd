class_name ClocktowerMovingPlatform
extends AnimatableBody2D

## 巨钟塔第三层左右移动跳跃平台 (Horizontal Moving Platform)
## 带有物理同步、正弦平滑巡航、相位偏移与药水冰冻交互

@export var move_distance: float = 240.0
@export var move_speed: float = 90.0
@export var move_phase: float = 0.0
@export var is_sync_controlled: bool = true

var _initial_pos: Vector2
var _time_elapsed: float = 0.0
var _is_frozen: bool = false
var _frozen_timer: float = 0.0
var _speed_multiplier: float = 1.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	sync_to_physics = true
	_initial_pos = position
	_time_elapsed = move_phase


func receive_potion_hit(hit: Dictionary) -> void:
	if PotionCapabilityResolver.hit_has_capability(hit, &"freeze"):
		_is_frozen = true
		_frozen_timer = 4.5
		if sprite != null:
			sprite.modulate = Color(0.4, 0.8, 1.4)
	elif PotionCapabilityResolver.hit_has_capability(hit, &"machine_drive"):
		_speed_multiplier = 1.8
		var tween := create_tween()
		if tween != null:
			tween.tween_property(self, "_speed_multiplier", 1.0, 5.0)


func set_slowdown(factor: float, duration: float) -> void:
	_speed_multiplier = factor
	var tween := create_tween()
	if tween != null:
		tween.tween_property(self, "_speed_multiplier", 1.0, duration)


func _physics_process(delta: float) -> void:
	if _is_frozen:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0:
			_is_frozen = false
			if sprite != null:
				sprite.modulate = Color.WHITE
		return

	_time_elapsed += delta * _speed_multiplier
	var cycle_length := (move_distance * 2.0) / maxf(move_speed, 1.0)
	var sin_val := sin((_time_elapsed / cycle_length) * TAU)
	
	position.x = _initial_pos.x + sin_val * (move_distance * 0.5)

class_name WinchLift
extends AnimatableBody2D

## Moving winch / crane lift platform for Aurem Clockyard platforming puzzle
## Can move between two positions on a periodic cycle or toggle on lever/potion interaction.

@export var move_offset: Vector2 = Vector2(0, -180)
@export var move_duration: float = 2.5
@export var is_automatic: bool = true
@export var pause_time: float = 1.0
@export var start_delay: float = 0.0

var _initial_pos: Vector2
var _target_pos: Vector2
var _progress: float = 0.0
var _moving_to_target: bool = true
var _pause_timer: float = 0.0
var _is_frozen: bool = false
var _frozen_timer: float = 0.0
var _manual_target_progress: float = 0.0

@onready var chain_line: Line2D = get_node_or_null("ChainLine")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	sync_to_physics = true
	_init_positions()
	_pause_timer = start_delay
	if not is_automatic:
		_moving_to_target = false
		_manual_target_progress = 0.0


func _init_positions() -> void:
	_initial_pos = position
	_target_pos = _initial_pos + move_offset


func get_target_position() -> Vector2:
	if _target_pos == Vector2.ZERO and _initial_pos == Vector2.ZERO:
		return position + move_offset
	return _target_pos


func toggle_lift() -> void:
	if _is_frozen:
		return

	if _target_pos == Vector2.ZERO and _initial_pos == Vector2.ZERO:
		_init_positions()

	if is_automatic:
		_moving_to_target = not _moving_to_target
		_pause_timer = 0.0
	else:
		_manual_target_progress = 1.0 if _manual_target_progress <= 0.5 else 0.0

	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_gear_clack"):
				audio.call("play_gear_clack")


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: String = String(hit.get("potion_id", ""))
	if "blue" in potion_id or "ice" in potion_id or "cyan" in potion_id:
		_is_frozen = true
		_frozen_timer = 4.0
		if sprite != null:
			sprite.modulate = Color(0.5, 0.8, 1.4)
	elif "orange" in potion_id or "speed" in potion_id:
		toggle_lift()
	elif "red" in potion_id:
		toggle_lift()


func _physics_process(delta: float) -> void:
	if _is_frozen:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0:
			_is_frozen = false
			if sprite != null:
				sprite.modulate = Color.WHITE
		return

	if _target_pos == Vector2.ZERO and _initial_pos == Vector2.ZERO:
		_init_positions()

	var speed := 1.0 / maxf(move_duration, 0.1)

	if is_automatic:
		if _pause_timer > 0.0:
			_pause_timer -= delta
			return

		if _moving_to_target:
			_progress = minf(_progress + speed * delta, 1.0)
			if _progress >= 1.0:
				_moving_to_target = false
				_pause_timer = pause_time
		else:
			_progress = maxf(_progress - speed * delta, 0.0)
			if _progress <= 0.0:
				_moving_to_target = true
				_pause_timer = pause_time
	else:
		if _progress < _manual_target_progress:
			_progress = minf(_progress + speed * delta, _manual_target_progress)
		elif _progress > _manual_target_progress:
			_progress = maxf(_progress - speed * delta, _manual_target_progress)

	# Smooth sine interpolation
	var smooth_t := (1.0 - cos(_progress * PI)) * 0.5
	position = _initial_pos.lerp(_target_pos, smooth_t)

	if chain_line != null:
		chain_line.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -position.y)])

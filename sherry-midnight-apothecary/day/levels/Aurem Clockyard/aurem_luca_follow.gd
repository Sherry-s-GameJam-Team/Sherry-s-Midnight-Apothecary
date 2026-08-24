class_name AuremLucaFollow
extends Node

## Scene-local companion movement for the Clockyard epilogue and its road transition.

@export var player_path: NodePath
@export var luca_path: NodePath
@export_range(20.0, 480.0, 4.0, "suffix:px") var stop_distance := 120.0
@export_range(20.0, 640.0, 4.0, "suffix:px") var follow_distance := 210.0
@export_range(80.0, 1600.0, 10.0, "suffix:px") var catch_up_distance := 520.0
@export_range(10.0, 1000.0, 5.0, "suffix:px/s") var follow_speed := 300.0
@export_range(10.0, 1400.0, 5.0, "suffix:px/s") var catch_up_speed := 460.0

var _player: CharacterBody2D
var _luca: LucaPlayer
var _luca_default_speed := 0.0
var _is_following := false
var _follow_enabled := false


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_luca = get_node_or_null(luca_path) as LucaPlayer
	if _luca == null:
		push_warning("AuremLucaFollow requires a LucaPlayer at luca_path.")
		set_physics_process(false)
		return
	_luca.input_enabled = false
	_luca_default_speed = _luca.move_speed
	set_physics_process(_follow_enabled)


func _physics_process(_delta: float) -> void:
	if not _follow_enabled or _player == null or _luca == null:
		return
	var horizontal_gap := _player.global_position.x - _luca.global_position.x
	var distance := absf(horizontal_gap)
	if not _is_following and distance >= follow_distance:
		_is_following = true
	elif _is_following and distance <= stop_distance:
		_is_following = false
	if not _is_following:
		_luca.move_speed = _luca_default_speed
		_luca.set_movement_direction(0.0)
		return
	_luca.move_speed = catch_up_speed if distance >= catch_up_distance else follow_speed
	_luca.set_movement_direction(signf(horizontal_gap))


func set_follow_enabled(enabled: bool) -> void:
	_follow_enabled = enabled
	_is_following = false
	if not is_node_ready():
		return
	set_physics_process(enabled and _luca != null)
	if _luca != null:
		_luca.input_enabled = false
		_luca.move_speed = _luca_default_speed
		_luca.set_movement_direction(0.0)


func is_follow_enabled() -> bool:
	return _follow_enabled

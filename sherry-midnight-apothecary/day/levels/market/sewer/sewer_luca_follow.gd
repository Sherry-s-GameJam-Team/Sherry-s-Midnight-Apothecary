class_name SewerLucaFollow
extends Node

## Scene-local companion movement for the narrow old aqueduct. Luca remains an
## autonomous follower here; this does not alter the shared dual-character
## controller contract used by later levels.
@export var player_path: NodePath
@export var luca_path: NodePath
@export_range(32.0, 480.0, 4.0, "suffix:px") var stop_distance := 140.0
@export_range(32.0, 640.0, 4.0, "suffix:px") var follow_distance := 250.0
@export_range(100.0, 1600.0, 10.0, "suffix:px") var catch_up_distance := 620.0
@export_range(50.0, 1000.0, 10.0, "suffix:px/s") var follow_speed := 340.0
@export_range(50.0, 1400.0, 10.0, "suffix:px/s") var catch_up_speed := 520.0

var _player: CharacterBody2D
var _luca: LucaPlayer
var _luca_default_speed := 0.0
var _is_following := false


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_luca = get_node_or_null(luca_path) as LucaPlayer
	if _luca == null:
		push_warning("SewerLucaFollow requires a LucaPlayer at luca_path.")
		set_physics_process(false)
		return
	_luca.input_enabled = false
	_luca_default_speed = _luca.move_speed


func _physics_process(_delta: float) -> void:
	if _player == null or _luca == null:
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

	# Keeping a larger activation gap than the stopping gap prevents foot-to-foot
	# jitter. The higher speed only engages after Sherry has substantially pulled
	# ahead, so Luca catches up without constantly running beside her.
	_luca.move_speed = catch_up_speed if distance >= catch_up_distance else follow_speed
	_luca.set_movement_direction(signf(horizontal_gap))

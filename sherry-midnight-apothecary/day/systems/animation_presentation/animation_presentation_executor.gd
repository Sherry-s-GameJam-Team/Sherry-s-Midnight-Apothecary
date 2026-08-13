class_name AnimationPresentationExecutor
extends Node

## Plays a one-shot AnimatedSprite2D before revealing a locked player at a marker.
## Configure the three node paths in each scene that uses this component.

signal completed

@export_node_path("AnimatedSprite2D") var animation_path: NodePath
@export_node_path("CharacterBody2D") var player_path: NodePath
@export_node_path("CanvasItem") var player_visual_path: NodePath
@export_node_path("Marker2D") var spawn_point_path: NodePath
@export var auto_start := true
@export var one_shot_per_day := false
@export var daily_flag_id: StringName = &""
@export var restore_player_control_on_complete := false

var _animation: AnimatedSprite2D
var _player: CharacterBody2D
var _player_visual: CanvasItem
var _spawn_point: Marker2D
var _previous_visual_visibility := true
var _previous_process_enabled := true
var _previous_physics_process_enabled := true
var _previous_input_enabled := true
var _previous_unhandled_input_enabled := true
var _previous_unhandled_key_input_enabled := true
var _running := false
var _has_completed := false
var _prepared := false


func _ready() -> void:
	if auto_start:
		call_deferred("start")


func start(force_replay := false) -> bool:
	if _running or _has_completed:
		return false
	if not _prepared and not prepare():
		return false
	if one_shot_per_day and not force_replay and _has_played_today():
		# DayRuntime has already placed the player at the requested entry marker.
		# Skipping a one-shot presentation must preserve that position (for
		# example, Home -> Bedroom uses EntryPoints/right_side).
		_complete_presentation(false)
		return true
	_running = true
	_mark_played_today()
	_animation.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)
	_animation.frame = 0
	_animation.frame_progress = 0.0
	_animation.play()
	return true


func prepare() -> bool:
	if _prepared:
		return true
	if not _resolve_nodes() or not _validate_animation():
		return false
	_previous_process_enabled = _player.is_processing()
	_previous_physics_process_enabled = _player.is_physics_processing()
	_previous_input_enabled = _player.is_processing_input()
	_previous_unhandled_input_enabled = _player.is_processing_unhandled_input()
	_previous_unhandled_key_input_enabled = _player.is_processing_unhandled_key_input()
	_previous_visual_visibility = _player_visual.visible
	_player_visual.visible = false
	# Disable only the player's own gameplay callbacks. Disabling process_mode
	# would also stop its Camera2D child and expose an invalid gray viewport.
	_player.set_process(false)
	_player.set_physics_process(false)
	_player.set_process_input(false)
	_player.set_process_unhandled_input(false)
	_player.set_process_unhandled_key_input(false)
	_prepared = true
	return true


func is_completed() -> bool:
	return _has_completed


func _resolve_nodes() -> bool:
	_animation = get_node_or_null(animation_path) as AnimatedSprite2D
	_player = get_node_or_null(player_path) as CharacterBody2D
	_player_visual = get_node_or_null(player_visual_path) as CanvasItem if not player_visual_path.is_empty() else _player
	_spawn_point = get_node_or_null(spawn_point_path) as Marker2D
	if _animation == null or _player == null or _player_visual == null or _spawn_point == null:
		push_error("AnimationPresentationExecutor requires valid animation, player, player visual, and spawn point paths.")
		return false
	return true


func _validate_animation() -> bool:
	if _animation.sprite_frames == null or not _animation.sprite_frames.has_animation(_animation.animation):
		push_error("AnimationPresentationExecutor requires an assigned SpriteFrames animation.")
		return false
	if _animation.sprite_frames.get_animation_loop(_animation.animation):
		push_error("AnimationPresentationExecutor only supports non-looping animations.")
		return false
	return true


func _on_animation_finished() -> void:
	if not _running or _has_completed:
		return
	_running = false
	# Remove the presentation artwork before revealing the gameplay character.
	# AnimatedSprite2D keeps its final frame for the rest of the current render
	# tick, so revealing synchronously produces a short double-exposure flash.
	if is_instance_valid(_animation):
		_animation.hide()
		_animation.stop()
	await get_tree().process_frame
	if not is_inside_tree() or _has_completed:
		return
	_complete_presentation()


func _complete_presentation(move_to_spawn := true) -> void:
	if _has_completed:
		return
	_has_completed = true
	if is_instance_valid(_player):
		if move_to_spawn and is_instance_valid(_spawn_point):
			_player.global_position = _spawn_point.global_position
		_player.set_process(true if restore_player_control_on_complete else _previous_process_enabled)
		_player.set_physics_process(true if restore_player_control_on_complete else _previous_physics_process_enabled)
		_player.set_process_input(true if restore_player_control_on_complete else _previous_input_enabled)
		_player.set_process_unhandled_input(true if restore_player_control_on_complete else _previous_unhandled_input_enabled)
		_player.set_process_unhandled_key_input(true if restore_player_control_on_complete else _previous_unhandled_key_input_enabled)
	if is_instance_valid(_player_visual):
		_player_visual.visible = _previous_visual_visibility
	if is_instance_valid(_animation):
		_animation.queue_free()
	completed.emit()


func _has_played_today() -> bool:
	var runtime := _find_day_runtime()
	if runtime == null or daily_flag_id.is_empty():
		return false
	var player_data := runtime.call("get_player_data") as PlayerData
	if player_data == null:
		return false
	return bool(player_data.tutorial_flags.get(_daily_flag_key(runtime), false))


func _mark_played_today() -> void:
	var runtime := _find_day_runtime()
	if runtime == null or daily_flag_id.is_empty():
		return
	var player_data := runtime.call("get_player_data") as PlayerData
	if player_data != null:
		player_data.tutorial_flags[_daily_flag_key(runtime)] = true


func _daily_flag_key(runtime: Node) -> String:
	return "%s_day_%d" % [daily_flag_id, int(runtime.get("day"))]


func _find_day_runtime() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data") and current.has_method("switch_to_level"):
			return current
		current = current.get_parent()
	return null

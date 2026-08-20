class_name TownIssueDayOne
extends Node2D

## First-day Town performance. It owns only local presentation; the persistent
## story event still owns dialogue completion, rewards, and save-state flags.

const EVENT_ID: StringName = &"day_one_blood_fountain"
const INTERACTION_KEY: StringName = &"issue_day_one_fountain"

@export_node_path("CharacterBody2D") var player_path: NodePath
@export_node_path("Camera2D") var camera_path: NodePath
@export_node_path("Sprite2D") var people_path: NodePath
@export_node_path("Marker2D") var sherry_position_path: NodePath
@export_node_path("Marker2D") var luca_position_path: NodePath
@export_node_path("LucaPlayer") var luca_path: NodePath
@export_range(40.0, 400.0, 5.0, "suffix:px/s") var entrance_walk_speed := 220.0
@export_range(16.0, 200.0, 1.0, "suffix:px") var offscreen_margin := 72.0

var _player: CharacterBody2D
var _camera: Camera2D
var _people: Sprite2D
var _sherry_position: Marker2D
var _luca_position: Marker2D
var _luca: LucaPlayer
var _runtime: DayRuntime
var _player_physics_was_enabled := true
var _camera_top_level_was_enabled := false
var _modal_lock_was_set := false
var _running := false


func _ready() -> void:
	_resolve_nodes()
	visible = false
	if _luca != null:
		_luca.set_physics_process(false)
		_luca.collision_layer = 0
		_luca.collision_mask = 0
	set_process(false)
	call_deferred("_start_if_needed")


func _process(_delta: float) -> void:
	if _running and _player_data().has_event_flag(_completion_flag()):
		_finish()


func _exit_tree() -> void:
	if _running:
		_restore_player_and_camera()


func _start_if_needed() -> void:
	if not _should_present():
		return
	if not _nodes_are_valid():
		push_error("Town issueDay1 is missing a required presentation node.")
		return
	_running = true
	visible = true
	set_process(true)
	_player_physics_was_enabled = _player.is_physics_processing()
	_player.set_physics_process(false)
	_player.velocity = Vector2.ZERO
	_luca.global_position = _luca_position.global_position
	_luca.input_enabled = false
	_luca.stop_moving()
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	_focus_people_camera()
	await _walk_sherry_in()
	if not _running or not is_inside_tree():
		return
	if not _runtime.dispatch_story_event_interaction(INTERACTION_KEY):
		push_error("Town issueDay1 could not dispatch its story event.")
		_finish()


func _walk_sherry_in() -> void:
	var visible_width := get_viewport().get_visible_rect().size.x / maxf(absf(_camera.zoom.x), 0.001)
	var entrance_x := _camera.global_position.x - visible_width * 0.5 - offscreen_margin
	_player.global_position = Vector2(entrance_x, _sherry_position.global_position.y)
	_play_sherry_animation(&"walk_right")
	var duration := absf(_sherry_position.global_position.x - entrance_x) / entrance_walk_speed
	var tween := create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(_player, "global_position:x", _sherry_position.global_position.x, duration)
	await tween.finished
	if is_instance_valid(_player):
		_player.global_position = _sherry_position.global_position
		_play_sherry_animation(&"idle_right")


func _focus_people_camera() -> void:
	_camera_top_level_was_enabled = _camera.top_level
	_camera.top_level = true
	# Preserve the normal vertical framing, which keeps Town's authored artwork
	# covering the viewport while centering the crowd horizontally.
	_camera.global_position = Vector2(_people.global_position.x, _camera.global_position.y)
	_camera.force_update_scroll()


func _finish() -> void:
	if not _running:
		return
	_running = false
	set_process(false)
	visible = false
	_restore_player_and_camera()


func _restore_player_and_camera() -> void:
	if is_instance_valid(_camera):
		_camera.top_level = _camera_top_level_was_enabled
		_camera.force_update_scroll()
	if is_instance_valid(_player):
		_player.set_physics_process(_player_physics_was_enabled)
	if get_tree() != null and not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")


func _should_present() -> bool:
	return _runtime != null \
		and _runtime.day == 1 \
		and _player_data() != null \
		and not _player_data().has_event_flag(_completion_flag())


func _completion_flag() -> StringName:
	return StringName("story_event_completed:%s" % EVENT_ID)


func _player_data() -> PlayerData:
	return _runtime.get_player_data() if _runtime != null else null


func _play_sherry_animation(animation_name: StringName) -> void:
	var animation_player := _player.get_node_or_null("SherryPresentation/SherryAnimationPlayer") as AnimationPlayer
	if animation_player != null:
		animation_player.play(animation_name)


func _resolve_nodes() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_camera = get_node_or_null(camera_path) as Camera2D
	_people = get_node_or_null(people_path) as Sprite2D
	_sherry_position = get_node_or_null(sherry_position_path) as Marker2D
	_luca_position = get_node_or_null(luca_position_path) as Marker2D
	_luca = get_node_or_null(luca_path) as LucaPlayer
	var current: Node = get_parent()
	while current != null:
		if current is DayRuntime:
			_runtime = current
			break
		current = current.get_parent()


func _nodes_are_valid() -> bool:
	return _player != null and _camera != null and _people != null and _sherry_position != null and _luca_position != null and _luca != null and _runtime != null

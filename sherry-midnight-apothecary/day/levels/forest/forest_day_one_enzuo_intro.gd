class_name ForestDayOneEnzuoIntro
extends Node2D

## First arrival presentation for the suspended boy in the forest. Persistent
## completion remains owned by StoryEventRunner; this node only coordinates
## local camera, character, fade, and staged dialogue presentation.

const ACTIVE_DAY := 1
const EVENT_ID: StringName = &"day_one_forest_enzuo_intro"
const INTERACTION_KEY: StringName = &"day_one_forest_enzuo_intro"
const SOLVED_FLAG: StringName = &"save_enzuo_solved"
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export var dialogue_resource: DialogueResource
@export_node_path("CharacterBody2D") var player_path: NodePath
@export_node_path("LucaPlayer") var luca_path: NodePath
@export_node_path("Camera2D") var camera_path: NodePath
@export_node_path("Marker2D") var sherry_position_path: NodePath
@export_node_path("Marker2D") var luca_position_path: NodePath
@export_node_path("AnimatedSprite2D") var hanging_npc_path: NodePath
@export_node_path("ColorRect") var fade_overlay_path: NodePath
@export_range(40.0, 400.0, 5.0, "suffix:px/s") var entrance_walk_speed := 220.0
@export_range(16.0, 200.0, 1.0, "suffix:px") var offscreen_margin := 72.0
@export_range(0.05, 2.0, 0.05) var fade_duration := 0.55

var _player: CharacterBody2D
var _luca: LucaPlayer
var _camera: Camera2D
var _sherry_position: Marker2D
var _luca_position: Marker2D
var _hanging_npc: AnimatedSprite2D
var _fade_overlay: ColorRect
var _runtime: DayRuntime
var _player_physics_was_enabled := true
var _luca_physics_was_enabled := true
var _camera_top_level_was_enabled := false
var _modal_lock_was_set := false
var _running := false


func _ready() -> void:
	_resolve_nodes()
	visible = should_show(_current_day(), _player_data())
	if _hanging_npc != null:
		_hanging_npc.position = Vector2(385.0, 118.0) if _has_completed_intro() else Vector2(385.0, -90.0)
	if _fade_overlay != null:
		_fade_overlay.visible = false
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if should_play_intro():
		visible = false
		call_deferred("_start_intro")


func _exit_tree() -> void:
	if _running:
		_cleanup()


static func should_show(day: int, player_data: PlayerData) -> bool:
	return day == ACTIVE_DAY and player_data != null and not player_data.has_event_flag(SOLVED_FLAG)


func should_play_intro() -> bool:
	return should_show(_current_day(), _player_data()) and not _has_completed_intro()


func _start_intro() -> void:
	if not should_play_intro() or not _nodes_are_valid():
		return
	_running = true
	_lock_presentation()
	await _play_dialogue(&"blackout")
	if not _running or not is_inside_tree():
		return
	visible = true
	await _fade_to(0.0)
	await _walk_party_in()
	if not _running or not is_inside_tree():
		return
	await _play_dialogue(&"arrival")
	await _move_hanging_npc(-22.0)
	await _play_dialogue(&"legs")
	await _move_hanging_npc(118.0)
	await _play_dialogue(&"rescue")
	_request_completion()


func _lock_presentation() -> void:
	_player_physics_was_enabled = _player.is_physics_processing()
	_luca_physics_was_enabled = _luca.is_physics_processing()
	_player.velocity = Vector2.ZERO
	_luca.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	_luca.set_physics_process(false)
	_player.set_dialogue_locked(true)
	_luca.set_control_enabled(false)
	_luca.visible = true
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	_camera_top_level_was_enabled = _camera.top_level
	_camera.top_level = true
	_camera.global_position = _sherry_position.global_position + Vector2(100.0, -130.0)
	_camera.force_update_scroll()
	_fade_overlay.visible = true
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_overlay.color.a = 1.0


func _walk_party_in() -> void:
	var visible_width := get_viewport().get_visible_rect().size.x / maxf(absf(_camera.zoom.x), 0.001)
	var entrance_x := _camera.global_position.x - visible_width * 0.5 - offscreen_margin
	_player.global_position = Vector2(entrance_x, _sherry_position.global_position.y)
	_luca.global_position = Vector2(entrance_x - 54.0, _luca_position.global_position.y)
	_play_sherry_animation(&"walk_right")
	_play_luca_animation(&"run_loop", true)
	var sherry_duration := absf(_sherry_position.global_position.x - entrance_x) / entrance_walk_speed
	var luca_duration := absf(_luca_position.global_position.x - _luca.global_position.x) / entrance_walk_speed
	var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_parallel(true)
	tween.tween_property(_player, "global_position:x", _sherry_position.global_position.x, sherry_duration)
	tween.tween_property(_luca, "global_position:x", _luca_position.global_position.x, luca_duration)
	await tween.finished
	_player.global_position = _sherry_position.global_position
	_luca.global_position = _luca_position.global_position
	_play_sherry_animation(&"idle_right")
	_play_luca_animation(&"idle", true)


func _move_hanging_npc(target_y: float) -> void:
	if _hanging_npc == null:
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_hanging_npc, "position:y", target_y, 0.65)
	await tween.finished


func _play_dialogue(title: StringName) -> void:
	if dialogue_resource == null:
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager") as Node
	if dialogue_manager == null or not dialogue_manager.has_method("show_dialogue_balloon_scene"):
		push_error("ForestDayOneEnzuoIntro requires the DialogueManager autoload.")
		return
	var balloon := dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue_resource, title) as Node
	if balloon != null:
		await balloon.tree_exited


func _request_completion() -> void:
	if _runtime == null or not _runtime.dispatch_story_event_interaction(INTERACTION_KEY):
		_cleanup()
		return
	_runtime.story_event_completed.connect(_on_story_event_completed, CONNECT_ONE_SHOT)


func _on_story_event_completed(event_id: StringName) -> void:
	if event_id == EVENT_ID:
		_cleanup()


func _fade_to(alpha: float) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_fade_overlay, "color:a", alpha, fade_duration)
	await tween.finished
	if is_zero_approx(alpha):
		_fade_overlay.visible = false
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _cleanup() -> void:
	if not _running:
		return
	_running = false
	if is_instance_valid(_camera):
		_camera.top_level = _camera_top_level_was_enabled
		_camera.force_update_scroll()
	if is_instance_valid(_player):
		_player.set_physics_process(_player_physics_was_enabled)
		_player.set_dialogue_locked(false)
	if is_instance_valid(_luca):
		_luca.set_physics_process(_luca_physics_was_enabled)
		_luca.set_control_enabled(true)
		_luca.visible = false
	if get_tree() != null and not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")
	if is_instance_valid(_fade_overlay):
		_fade_overlay.visible = false
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_overlay.color.a = 0.0


func _play_sherry_animation(animation_name: StringName) -> void:
	var animation_player := _player.get_node_or_null("SherryPresentation/SherryAnimationPlayer") as AnimationPlayer
	if animation_player != null:
		animation_player.play(animation_name)


func _play_luca_animation(animation_name: StringName, face_right: bool) -> void:
	var sprite := _luca.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.flip_h = face_right
		sprite.play(animation_name)


func _has_completed_intro() -> bool:
	return _runtime != null and _runtime.has_completed_story_event(EVENT_ID)


func _current_day() -> int:
	return _runtime.day if _runtime != null else -1


func _player_data() -> PlayerData:
	return _runtime.get_player_data() if _runtime != null else null


func _resolve_nodes() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_luca = get_node_or_null(luca_path) as LucaPlayer
	_camera = get_node_or_null(camera_path) as Camera2D
	_sherry_position = get_node_or_null(sherry_position_path) as Marker2D
	_luca_position = get_node_or_null(luca_position_path) as Marker2D
	_hanging_npc = get_node_or_null(hanging_npc_path) as AnimatedSprite2D
	_fade_overlay = get_node_or_null(fade_overlay_path) as ColorRect
	var current: Node = get_parent()
	while current != null:
		if current is DayRuntime:
			_runtime = current
			break
		current = current.get_parent()


func _nodes_are_valid() -> bool:
	return _player != null and _luca != null and _camera != null and _sherry_position != null and _luca_position != null and _hanging_npc != null and _fade_overlay != null and _runtime != null

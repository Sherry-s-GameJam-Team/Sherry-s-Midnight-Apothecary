class_name HomeDayOneIntro
extends Node

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const COMPLETED_FLAG := "home_day_1_npc_intro_played"

@export var dialogue_resource: DialogueResource
@export var dialogue_title := "start"
@export_node_path("CharacterBody2D") var player_path: NodePath
@export_node_path("HomeCameraDirector") var camera_director_path: NodePath
@export_node_path("Marker2D") var trigger_marker_path: NodePath
@export_node_path("CanvasItem") var young_knight_path: NodePath
@export_node_path("CanvasItem") var senior_knight_path: NodePath
@export_node_path("ColorRect") var fade_overlay_path: NodePath
@export_range(8.0, 240.0, 1.0) var trigger_radius := 80.0
@export_range(0.05, 2.0, 0.05) var fade_duration := 0.35
@export var cinematic_camera_position := Vector2(746.5, 508.0)

var _player: CharacterBody2D
var _camera_director: HomeCameraDirector
var _trigger_marker: Marker2D
var _young_knight: CanvasItem
var _senior_knight: CanvasItem
var _fade_overlay: ColorRect
var _player_physics_was_enabled := true
var _modal_lock_was_set := false
var _running := false
var _cleanup_complete := false
var _balloon: Node


func _ready() -> void:
	_resolve_nodes()
	_set_npcs_visible(should_present(_current_day(), _find_player_data()))
	if _fade_overlay != null:
		_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(should_present(_current_day(), _find_player_data()))


func _process(_delta: float) -> void:
	if _running or _player == null or _trigger_marker == null:
		return
	if not should_present(_current_day(), _find_player_data()):
		set_process(false)
		_set_npcs_visible(false)
		return
	if has_reached_trigger(_player.global_position, _trigger_marker.global_position, trigger_radius):
		set_process(false)
		_start_intro()


func _exit_tree() -> void:
	if _running:
		_cleanup()


static func should_present(day: int, player_data: PlayerData) -> bool:
	return day == 1 and player_data != null and not bool(player_data.tutorial_flags.get(COMPLETED_FLAG, false))


static func has_reached_trigger(player_position: Vector2, marker_position: Vector2, radius: float) -> bool:
	return absf(player_position.x - marker_position.x) <= radius


func _start_intro() -> void:
	if not _nodes_are_valid():
		push_error("HomeDayOneIntro is missing a required scene node.")
		_set_npcs_visible(false)
		return
	var player_data := _find_player_data()
	player_data.tutorial_flags[COMPLETED_FLAG] = true
	_running = true
	_cleanup_complete = false
	_player_physics_was_enabled = _player.is_physics_processing()
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(false)
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	_camera_director.hide_entrance_hint()
	_camera_director.focus_cinematic_camera(cinematic_camera_position)
	if not _camera_director.is_cinematic_focus_reached():
		await _camera_director.cinematic_focus_reached
	if not _running or not is_inside_tree():
		return
	_start_dialogue()


func _start_dialogue() -> void:
	if dialogue_resource == null:
		push_error("HomeDayOneIntro requires a dialogue resource.")
		await _depart_and_finish()
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("HomeDayOneIntro requires the DialogueManager autoload.")
		await _depart_and_finish()
		return
	_balloon = dialogue_manager.show_dialogue_balloon_scene(
		BALLOON_SCENE,
		dialogue_resource,
		dialogue_title
	)
	if _balloon == null:
		await _depart_and_finish()
		return
	_balloon.tree_exited.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)


func _on_dialogue_finished() -> void:
	_balloon = null
	if _running:
		_depart_and_finish()


func _depart_and_finish() -> void:
	if not _running:
		return
	await _fade_to(1.0)
	if not _running:
		return
	_set_npcs_visible(false)
	await _fade_to(0.0)
	_cleanup()


func _fade_to(alpha: float) -> void:
	if _fade_overlay == null:
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade_overlay, "color:a", alpha, fade_duration)
	await tween.finished


func _cleanup() -> void:
	if _cleanup_complete:
		return
	_cleanup_complete = true
	_running = false
	if is_instance_valid(_camera_director):
		_camera_director.release_cinematic_camera()
	if is_instance_valid(_player):
		_player.set_physics_process(_player_physics_was_enabled)
	if get_tree() != null and not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")
	if is_instance_valid(_fade_overlay):
		_fade_overlay.color.a = 0.0


func _resolve_nodes() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_camera_director = get_node_or_null(camera_director_path) as HomeCameraDirector
	_trigger_marker = get_node_or_null(trigger_marker_path) as Marker2D
	_young_knight = get_node_or_null(young_knight_path) as CanvasItem
	_senior_knight = get_node_or_null(senior_knight_path) as CanvasItem
	_fade_overlay = get_node_or_null(fade_overlay_path) as ColorRect


func _nodes_are_valid() -> bool:
	return _player != null and _camera_director != null and _trigger_marker != null and _young_knight != null and _senior_knight != null and _fade_overlay != null


func _set_npcs_visible(visible: bool) -> void:
	if _young_knight != null:
		_young_knight.visible = visible
	if _senior_knight != null:
		_senior_knight.visible = visible


func _current_day() -> int:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("switch_to_level") and current.has_method("get_player_data"):
			return int(current.get("day"))
		current = current.get_parent()
	return 1


func _find_player_data() -> PlayerData:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data"):
			return current.call("get_player_data") as PlayerData
		current = current.get_parent()
	return null

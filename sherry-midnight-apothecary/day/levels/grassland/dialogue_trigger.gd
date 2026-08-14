class_name GrasslandDialogueTrigger
extends Area2D

## Plays dialog1 once, then carries Sherry on the floating Trapezoid into the
## Emerald Field platform level.

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

signal launch_requested

@export var dialogue_resource: DialogueResource
@export var dialogue_title := "start"
@export var seen_flag := "grassland_dialog1_seen"
@export_node_path("CharacterBody2D") var player_path := NodePath("../../Player")
@export_node_path("Node2D") var trapezoid_path := NodePath("../../Trapezoid")
@export_node_path("Camera2D") var camera_path := NodePath("../../Player/Camera2D")
@export var destination_level: StringName = &"emerald_field"
@export var boarding_offset := Vector2(-28.0, -72.0)
@export_range(0.1, 5.0, 0.05) var board_duration := 1.15
@export_range(0.1, 3.0, 0.05) var shake_duration := 0.75
@export_range(20.0, 400.0, 5.0) var hover_height := 96.0
@export_range(0.0, 3.0, 0.05) var hover_duration := 0.65
@export_range(0.1, 5.0, 0.05) var ascent_duration := 1.75
@export_range(200.0, 2400.0, 10.0) var ascent_height := 1160.0

var _triggered := false
var _cinematic_running := false
var _boarding_complete := false
var _launch_requested := false
var _balloon: Node
var _player: CharacterBody2D
var _trapezoid: Node2D
var _camera: Camera2D
var _player_parent: Node
var _player_physics_was_enabled := true
var _player_z_index := 0
var _trapezoid_start_position := Vector2.ZERO
var _trapezoid_start_rotation := 0.0
var _modal_lock_was_set := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if _has_been_seen():
		_triggered = true
		monitoring = false


func _exit_tree() -> void:
	if _cinematic_running and get_tree() != null and not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")


func _on_body_entered(body: Node2D) -> void:
	if _triggered or body.name != "Player" or dialogue_resource == null:
		return
	_triggered = true
	monitoring = false
	var player_data := _find_player_data()
	if player_data != null:
		player_data.tutorial_flags[seen_flag] = true
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("GrasslandDialogueTrigger requires the DialogueManager autoload.")
		return
	var extra_game_states: Array = []
	if player_data != null:
		extra_game_states.append({"player_data": player_data})
	_balloon = dialogue_manager.show_dialogue_balloon_scene(
		BALLOON_SCENE,
		dialogue_resource,
		dialogue_title,
		extra_game_states
	)
	if _balloon == null:
		push_error("GrasslandDialogueTrigger could not create the dialog1 balloon.")
		return
	if _balloon.has_signal("dialogue_event"):
		_balloon.connect("dialogue_event", _on_dialogue_event)
	_balloon.tree_exited.connect(_on_dialogue_finished, CONNECT_ONE_SHOT)


func _on_dialogue_event(event_name: StringName, _payload: Variant) -> void:
	match event_name:
		&"grassland_dialog1_board":
			_play_departure_cinematic()
		&"grassland_dialog1_launch":
			_request_launch()


func _on_dialogue_finished() -> void:
	_balloon = null
	if not _cinematic_running:
		_play_departure_cinematic()
	_request_launch()


func _request_launch() -> void:
	_launch_requested = true
	if _boarding_complete:
		launch_requested.emit()


func _play_departure_cinematic() -> void:
	if _cinematic_running:
		return
	_resolve_cinematic_nodes()
	if _player == null or _trapezoid == null:
		push_error("Grassland dialog1 cinematic requires Player and Trapezoid.")
		return
	_cinematic_running = true
	_boarding_complete = false
	_launch_requested = false
	_player_parent = _player.get_parent()
	_player_physics_was_enabled = _player.is_physics_processing()
	_player_z_index = _player.z_index
	_trapezoid_start_position = _trapezoid.position
	_trapezoid_start_rotation = _trapezoid.rotation
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	_player.velocity = Vector2.ZERO
	_player.set_dialogue_locked(true)
	_player.set_potion_action_locked(true)
	_player.set_physics_process(false)

	var animation_player := _player.get_node_or_null("SherryPresentation/SherryAnimationPlayer") as AnimationPlayer
	if animation_player != null:
		animation_player.play(&"walk_right")
	var board_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	board_tween.tween_property(_player, "global_position", _trapezoid.global_position + boarding_offset, board_duration)
	await board_tween.finished
	if not _cinematic_running or not is_instance_valid(_player) or not is_instance_valid(_trapezoid):
		return
	if animation_player != null:
		animation_player.play(&"idle_right")

	# Freeze the view at the takeoff point so the platform can actually leave the
	# camera frame instead of the player camera following it upward.
	if is_instance_valid(_camera):
		_camera.reparent(_trapezoid.get_parent(), true)
	_player.reparent(_trapezoid, true)
	_player.position = boarding_offset
	_player.z_index = 10

	var shake_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	shake_tween.tween_property(_trapezoid, "rotation", deg_to_rad(-4.0), shake_duration * 0.25)
	shake_tween.tween_property(_trapezoid, "rotation", deg_to_rad(4.0), shake_duration * 0.25)
	shake_tween.tween_property(_trapezoid, "rotation", deg_to_rad(-2.0), shake_duration * 0.25)
	shake_tween.tween_property(_trapezoid, "rotation", 0.0, shake_duration * 0.25)
	await shake_tween.finished
	if not _cinematic_running or not is_instance_valid(_trapezoid):
		return
	var hover_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	hover_tween.tween_property(
		_trapezoid,
		"position",
		Vector2(_trapezoid_start_position.x, _trapezoid_start_position.y - hover_height),
		0.45
	)
	await hover_tween.finished
	if not _cinematic_running:
		return
	await get_tree().create_timer(hover_duration).timeout
	if not _cinematic_running:
		return
	_boarding_complete = true
	if not _launch_requested:
		await launch_requested
	if not _cinematic_running:
		return

	var ascent_tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ascent_tween.tween_property(
		_trapezoid,
		"position",
		Vector2(_trapezoid_start_position.x, _trapezoid_start_position.y - ascent_height),
		ascent_duration
	)
	await ascent_tween.finished
	if not _cinematic_running:
		return
	_finish_cinematic_transition()


func _finish_cinematic_transition() -> void:
	_release_modal_lock()
	var runtime := _find_day_runtime()
	if runtime != null and runtime.switch_to_level(str(destination_level), &"default"):
		return
	_restore_cinematic_nodes()
	push_error("Grassland dialog1 cinematic could not switch to %s." % destination_level)


func _resolve_cinematic_nodes() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_trapezoid = get_node_or_null(trapezoid_path) as Node2D
	_camera = get_node_or_null(camera_path) as Camera2D


func _restore_cinematic_nodes() -> void:
	if is_instance_valid(_player):
		if is_instance_valid(_player_parent) and _player.get_parent() != _player_parent:
			_player.reparent(_player_parent, true)
		_player.z_index = _player_z_index
		_player.velocity = Vector2.ZERO
		_player.set_physics_process(_player_physics_was_enabled)
		_player.set_dialogue_locked(false)
		_player.set_potion_action_locked(false)
	if is_instance_valid(_camera) and is_instance_valid(_player) and _camera.get_parent() != _player:
		_camera.reparent(_player, true)
	if is_instance_valid(_trapezoid):
		_trapezoid.position = _trapezoid_start_position
		_trapezoid.rotation = _trapezoid_start_rotation
	_release_modal_lock()
	_cinematic_running = false
	_boarding_complete = false
	_launch_requested = false


func _release_modal_lock() -> void:
	if get_tree() != null and not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")


func _has_been_seen() -> bool:
	var player_data := _find_player_data()
	return player_data != null and bool(player_data.tutorial_flags.get(seen_flag, false))


func _find_player_data() -> PlayerData:
	var current: Node = self
	while current != null:
		if current.has_method("get_player_data"):
			return current.call("get_player_data") as PlayerData
		current = current.get_parent()
	return null


func _find_day_runtime() -> Node:
	var current: Node = self
	while current != null:
		if current.has_method("switch_to_level"):
			return current
		current = current.get_parent()
	return null

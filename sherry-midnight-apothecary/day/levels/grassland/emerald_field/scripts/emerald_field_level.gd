class_name EmeraldFieldLevel
extends DayLevelEnvironment

const MIASMA_PURIFIER_SCENE_PATH := "res://minigames/minigames/miasma_purifier/scenes/miasma_purifier_osu_minigame.tscn"
const MIASMA_CLEARED_FLAG := "emerald_field_miasma_cleared"
const MIASMA_RETURN_PENDING_FLAG := "grassland_miasma_completion_return_pending"

@export var respawn_position := Vector2(240.0, 410.0)
@export var fade_out_time := 0.18
@export var fade_in_time := 0.28

@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var player: CharacterBody2D = $Player
@onready var goal = $Goal

var _respawning := false
var _minigame: Node
var _miasma_completion_running := false
var _miasma_return_position := Vector2.ZERO


func _ready() -> void:
	super()
	respawn_position = player_spawn.global_position
	fade_rect.modulate.a = 0.0
	goal.minigame_requested.connect(_start_miasma_purifier)
	goal.set_available(not _is_miasma_cleared())


func request_respawn(body: Node2D, reason: String = "fall", damage: int = 0) -> void:
	if _respawning or not is_instance_valid(body):
		return
	var runtime := _get_day_runtime()
	if runtime != null and damage > 0 and runtime.apply_player_damage(damage, StringName(reason)):
		return
	_respawning = true
	_set_player_control(body, false)
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_rect, "modulate:a", 1.0, fade_out_time)
	await tween.finished

	if is_instance_valid(body):
		body.global_position = respawn_position
		if body is CharacterBody2D:
			body.velocity = Vector2.ZERO

	for node: Node in get_tree().get_nodes_in_group("resettable"):
		if is_ancestor_of(node) and node.has_method("reset_hazard"):
			node.call("reset_hazard")

	await get_tree().create_timer(0.06).timeout
	var tween_in := create_tween()
	tween_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, fade_in_time)
	await tween_in.finished

	if is_instance_valid(body):
		_set_player_control(body, true)
	_respawning = false


func _set_player_control(body: Node, enabled: bool) -> void:
	if body.has_method("set_control_enabled"):
		body.call("set_control_enabled", enabled)
		return
	# Current Sherry keeps physics and Camera2D processing during the fade.
	if body.has_method("set_dialogue_locked"):
		body.call("set_dialogue_locked", not enabled)
	if body.has_method("set_potion_action_locked"):
		body.call("set_potion_action_locked", not enabled)


func _start_miasma_purifier(return_position: Vector2) -> void:
	if _miasma_completion_running or is_instance_valid(_minigame) or _is_miasma_cleared():
		return
	_miasma_return_position = return_position
	_set_player_control(player, false)
	get_tree().set_meta("day_modal_input_locked", true)
	var minigame_scene: PackedScene = load(MIASMA_PURIFIER_SCENE_PATH) as PackedScene
	if minigame_scene == null:
		_set_player_control(player, true)
		get_tree().remove_meta("day_modal_input_locked")
		push_error("Unable to load miasma purifier scene: %s" % MIASMA_PURIFIER_SCENE_PATH)
		return
	_minigame = minigame_scene.instantiate()
	add_child(_minigame)
	_minigame.connect(&"minigame_completed", _on_miasma_purifier_succeeded, CONNECT_ONE_SHOT)


func _on_miasma_purifier_succeeded() -> void:
	if _miasma_completion_running:
		return
	_miasma_completion_running = true
	var data := _get_player_data()
	if data != null:
		data.tutorial_flags[MIASMA_CLEARED_FLAG] = true
		data.tutorial_flags[MIASMA_RETURN_PENDING_FLAG] = true
	# Keep the osu-style completion card visible before closing the minigame.
	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(_minigame):
		_minigame.queue_free()
		_minigame = null
	var player_camera := player.get_node_or_null("Camera2D") as Camera2D
	if player_camera != null:
		player_camera.make_current()
	player.global_position = _miasma_return_position
	await _shake_player_camera()
	var runtime := _get_day_runtime()
	if runtime != null:
		await runtime.transition_to_level_with_blackout("grassland", &"level_completed", true)
	else:
		_set_player_control(player, true)
		get_tree().remove_meta("day_modal_input_locked")
		_miasma_completion_running = false


func _shake_player_camera() -> void:
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var original_offset := camera.offset
	for _index in 8:
		camera.offset = original_offset + Vector2(randf_range(-10.0, 10.0), randf_range(-7.0, 7.0))
		await get_tree().create_timer(0.035).timeout
	camera.offset = original_offset


func _is_miasma_cleared() -> bool:
	var data := _get_player_data()
	return data != null and bool(data.tutorial_flags.get(MIASMA_CLEARED_FLAG, false))


func _get_player_data() -> PlayerData:
	var runtime := _get_day_runtime()
	return runtime.get_player_data() if runtime != null else null


func _get_day_runtime() -> Node:
	# Duck-typed on purpose: referencing DayRuntime here would create a
	# compile-time preload cycle (day_runtime.gd -> LEVELS -> level.tres ->
	# level.tscn -> this script -> DayRuntime). See day_runtime.gd header.
	var cursor: Node = get_parent()
	while cursor != null:
		if cursor.has_method("get_player_data"):
			return cursor
		cursor = cursor.get_parent()
	return null

class_name EmeraldFieldLevel
extends DayLevelEnvironment

const MIASMA_PURIFIER_SCENE := preload("res://day/minigames/miasma_purifier/miasma_purifier.tscn")
const MIASMA_CLEARED_FLAG := "emerald_field_miasma_cleared"

@export var respawn_position := Vector2(240.0, 410.0)
@export var fade_out_time := 0.18
@export var fade_in_time := 0.28

@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var player: CharacterBody2D = $Player
@onready var goal: Area2D = $Goal

var _respawning := false
var _minigame: MiasmaPurifier
var _miasma_completion_running := false
var _miasma_return_position := Vector2.ZERO


func _ready() -> void:
	super()
	respawn_position = player_spawn.global_position
	fade_rect.modulate.a = 0.0
	goal.minigame_requested.connect(_start_miasma_purifier)
	goal.set_available(not _is_miasma_cleared())


func request_respawn(body: Node2D, _reason: String = "fall") -> void:
	if _respawning or not is_instance_valid(body):
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
	_minigame = MIASMA_PURIFIER_SCENE.instantiate() as MiasmaPurifier
	add_child(_minigame)
	_minigame.succeeded.connect(_on_miasma_purifier_succeeded, CONNECT_ONE_SHOT)


func _on_miasma_purifier_succeeded() -> void:
	if _miasma_completion_running:
		return
	_miasma_completion_running = true
	var data := _get_player_data()
	if data != null:
		data.tutorial_flags[MIASMA_CLEARED_FLAG] = true
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


func _get_day_runtime() -> DayRuntime:
	var cursor: Node = get_parent()
	while cursor != null:
		if cursor is DayRuntime:
			return cursor as DayRuntime
		cursor = cursor.get_parent()
	return null

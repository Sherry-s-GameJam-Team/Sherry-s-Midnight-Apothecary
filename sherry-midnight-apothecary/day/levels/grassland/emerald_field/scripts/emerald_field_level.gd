class_name EmeraldFieldLevel
extends DayLevelEnvironment

@export var respawn_position := Vector2(240.0, 410.0)
@export var fade_out_time := 0.18
@export var fade_in_time := 0.28

@onready var fade_rect: ColorRect = $UI/FadeRect
@onready var player_spawn: Marker2D = $PlayerSpawn

var _respawning := false


func _ready() -> void:
	super()
	respawn_position = player_spawn.global_position
	fade_rect.modulate.a = 0.0


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

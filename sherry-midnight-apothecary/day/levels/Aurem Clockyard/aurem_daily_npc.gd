class_name AuremDailyNPC
extends Area2D

## Daily NPC for Aurem Clockyard (Gear Consciousness Lifeform).
## Supports stationary idle breathing or rolling wander, proximity prompt, and DialogueManager.

enum MovementType {
	STATIONARY,
	WANDER
}

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export var npc_name: String = "奥勒姆齿轮居民"
@export var movement_type: MovementType = MovementType.STATIONARY
@export var wander_radius: float = 200.0
@export var wander_speed: float = 65.0
@export var min_pause: float = 1.2
@export var max_pause: float = 3.5
@export_file("*.dialogue") var dialogue_path := "res://day/levels/Aurem Clockyard/aurem_daily_npcs.dialogue"
@export var dialogue_title: String = "otto_start"
@export var interaction_hint_text: String = "按[E]交谈"

@onready var presentation: Node2D = get_node_or_null("Presentation")
@onready var sprite: Sprite2D = get_node_or_null("Presentation/Sprite2D") if has_node("Presentation/Sprite2D") else get_node_or_null("Sprite2D")

var _origin_x: float = 0.0
var _wander_target_x: float = 0.0
var _pause_remaining: float = 0.0
var _player_in_range: bool = false
var _dialogue_open: bool = false
var _modal_lock_was_set: bool = false
var _rng := RandomNumberGenerator.new()
var _initial_sprite_scale_x: float = 1.0


func _ready() -> void:
	_origin_x = global_position.x
	_rng.randomize()
	if sprite != null:
		_initial_sprite_scale_x = absf(sprite.scale.x)

	if movement_type == MovementType.WANDER:
		_choose_wander_target()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if not visible:
		return

	# Amber core subtle luminous glow pulse
	if presentation != null:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.05
		presentation.modulate = Color(pulse, pulse * 0.98, pulse * 0.88, 1.0)

	# Idle breathing/floating for stationary NPCs
	if presentation != null and movement_type == MovementType.STATIONARY:
		presentation.position.y = sin(Time.get_ticks_msec() * 0.003) * 1.8

	if _dialogue_open:
		return

	if movement_type == MovementType.WANDER:
		if _pause_remaining > 0.0:
			_pause_remaining -= delta
			if presentation != null:
				presentation.rotation = move_toward(presentation.rotation, 0.0, 4.0 * delta)
			return

		var current_x := global_position.x
		var next_x := move_toward(current_x, _wander_target_x, wander_speed * delta)
		var dir := signf(_wander_target_x - current_x)
		if dir != 0.0 and sprite != null:
			sprite.scale.x = _initial_sprite_scale_x * (1.0 if dir > 0.0 else -1.0)
			if presentation != null:
				# Slight tilt when rolling forward
				presentation.rotation = deg_to_rad(4.0 * dir)

		global_position.x = next_x
		if is_equal_approx(next_x, _wander_target_x):
			if presentation != null:
				presentation.rotation = 0.0
			_pause_remaining = _rng.randf_range(min_pause, max_pause)
			_choose_wander_target()


func _input(event: InputEvent) -> void:
	if not visible or not _player_in_range or _dialogue_open or get_tree().has_meta("day_modal_input_locked") or not _is_interact_event(event):
		return
	get_viewport().set_input_as_handled()
	_open_dialogue()


func _exit_tree() -> void:
	_hide_hint()


func set_active(active: bool) -> void:
	visible = active
	monitoring = active
	monitorable = active
	set_process(active)
	set_process_input(active)
	if not active:
		_hide_hint()


func _choose_wander_target() -> void:
	_wander_target_x = _origin_x + _rng.randf_range(-wander_radius, wander_radius)


func _open_dialogue() -> void:
	var dialogue_resource := load(dialogue_path) as DialogueResource
	if dialogue_resource == null:
		push_error("AuremDailyNPC requires a valid dialogue resource.")
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("AuremDailyNPC requires DialogueManager.")
		return

	# Face the player when talking
	var player := _find_player()
	if player != null and sprite != null:
		var dir := signf(player.global_position.x - global_position.x)
		if dir != 0.0:
			sprite.scale.x = _initial_sprite_scale_x * (1.0 if dir > 0.0 else -1.0)
	if presentation != null:
		presentation.rotation = 0.0

	_dialogue_open = true
	_hide_hint()
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)

	var balloon := dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue_resource, dialogue_title) as Node
	if balloon == null:
		_finish_dialogue()
		return
	balloon.tree_exited.connect(_finish_dialogue, CONNECT_ONE_SHOT)


func _finish_dialogue() -> void:
	_dialogue_open = false
	if not _modal_lock_was_set and is_inside_tree() and get_tree() != null:
		get_tree().remove_meta("day_modal_input_locked")
	if _player_in_range:
		_show_hint()


func _on_body_entered(body: Node2D) -> void:
	if not visible:
		return
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		_player_in_range = true
		_show_hint()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player")):
		_player_in_range = false
		_hide_hint()


func _show_hint() -> void:
	var hint := _find_top_hint()
	if hint != null:
		var text := interaction_hint_text if not interaction_hint_text.is_empty() else ("按[E]与%s交谈" % npc_name)
		hint.show_interaction_hint(_hint_id(), text)


func _hide_hint() -> void:
	var hint := _find_top_hint()
	if hint != null:
		hint.hide_interaction_hint(_hint_id())


func _find_top_hint() -> TopHintUI:
	if not is_inside_tree() or get_tree() == null or get_tree().root == null:
		return null
	var hint := get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	return hint


func _find_player() -> Node2D:
	if not is_inside_tree() or get_tree() == null:
		return null
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null:
		return p
	if get_parent() != null:
		p = get_parent().get_node_or_null("../Player") as Node2D
		if p != null:
			return p
	return null


func _hint_id() -> String:
	return "daily_npc_%s" % get_instance_id()


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E)

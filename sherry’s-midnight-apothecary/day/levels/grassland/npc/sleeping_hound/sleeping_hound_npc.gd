class_name SleepingHoundNPC
extends Area2D

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export var dialogue_resource: DialogueResource
@export var dialogue_title := "start"
@export var interaction_hint_text := "按[E]与沉睡的魔犬交谈"
@export_range(1.0, 24.0, 0.5) var animation_fps := 6.0
@export_range(1, 120, 1) var animation_frame_count := 30

@onready var visual: Sprite2D = $Visual

var _animation_time := 0.0
var _player: CharacterBody2D
var _player_inside := false
var _dialogue_open := false
var _balloon: Node
var _modal_lock_was_set := false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	var cycle_frame_count: int = maxi(1, animation_frame_count * 2 - 2)
	_animation_time = fmod(_animation_time + delta, float(cycle_frame_count) / animation_fps)
	var cycle_frame: int = int(_animation_time * animation_fps) % cycle_frame_count
	visual.frame = cycle_frame if cycle_frame < animation_frame_count else cycle_frame_count - cycle_frame


func _input(event: InputEvent) -> void:
	if _dialogue_open or not _player_inside or not _is_interact_event(event):
		return
	get_viewport().set_input_as_handled()
	_start_dialogue()


func _exit_tree() -> void:
	if _dialogue_open:
		_finish_dialogue()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_player = body
		_player_inside = true
		_show_interaction_hint()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_inside = false
		_hide_interaction_hint()


func _start_dialogue() -> void:
	if dialogue_resource == null:
		push_error("SleepingHoundNPC requires a dialogue resource.")
		return
	_dialogue_open = true
	_hide_interaction_hint()
	if _player != null:
		_player.set_physics_process(false)
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	_balloon = DialogueManager.show_dialogue_balloon_scene(
		BALLOON_SCENE,
		dialogue_resource,
		dialogue_title
	)
	if _balloon == null:
		_finish_dialogue()
		return
	_balloon.tree_exited.connect(_finish_dialogue, CONNECT_ONE_SHOT)


func _finish_dialogue() -> void:
	if not _dialogue_open:
		return
	_dialogue_open = false
	_balloon = null
	if _player != null:
		_player.set_physics_process(true)
	if not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")
	if _player_inside:
		_show_interaction_hint()


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)


func _find_app_root() -> Node:
	var current: Node = self
	while current != null:
		if current.get_node_or_null("GlobalUI/TopHintUI") != null:
			return current
		current = current.get_parent()
	return get_tree().root


func _show_interaction_hint() -> void:
	var top_hint := _find_app_root().get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_interaction_hint() -> void:
	var top_hint := _find_app_root().get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _hint_id() -> String:
	return "interaction_%s" % get_instance_id()

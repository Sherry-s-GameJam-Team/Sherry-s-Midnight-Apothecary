class_name EnzuoNightNPC
extends Area2D

const ACTIVE_DAY := 1
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export var dialogue_resource: DialogueResource = preload("res://night/levels/home/enzuo_day_one.dialogue")
@export var dialogue_title: StringName = &"enzo_repeat_start"
@export var interaction_hint_text := "按[E]与恩佐交谈"

@onready var visual: AnimatedSprite2D = $Visual

var _player_inside := false
var _dialogue_open := false
var _interaction_enabled := false
var _modal_lock_was_set := false
var _balloon: Node


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if visual != null:
		visual.play(&"idle")
	configure_for_day(-1)


func configure_for_day(current_day: int) -> void:
	_interaction_enabled = current_day == ACTIVE_DAY
	visible = _interaction_enabled
	monitoring = _interaction_enabled
	monitorable = _interaction_enabled
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		collision.set_deferred("disabled", not _interaction_enabled)
	if not _interaction_enabled:
		_player_inside = false
		_hide_interaction_hint()


func _input(event: InputEvent) -> void:
	if not _interaction_enabled or _dialogue_open or not _player_inside or not _is_interact_event(event):
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	start_interaction()


func _exit_tree() -> void:
	_hide_interaction_hint()
	if _dialogue_open:
		_finish_dialogue()


func start_interaction() -> void:
	if dialogue_resource == null:
		push_error("EnzuoNightNPC requires a dialogue resource.")
		return
	_dialogue_open = true
	_hide_interaction_hint()
	_acquire_modal_lock()
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("EnzuoNightNPC requires DialogueManager autoload.")
		_finish_dialogue()
		return
	var extra_game_states: Array = []
	var player_data := _find_player_data()
	if player_data != null:
		extra_game_states.append({"player_data": player_data})
	_balloon = dialogue_manager.show_dialogue_balloon_scene(
		BALLOON_SCENE,
		dialogue_resource,
		str(dialogue_title),
		extra_game_states
	)
	if _balloon == null:
		_finish_dialogue()
		return
	_balloon.tree_exited.connect(_finish_dialogue, CONNECT_ONE_SHOT)


func _on_body_entered(body: Node2D) -> void:
	if _interaction_enabled and body is CharacterBody2D and body.name == "Player":
		_player_inside = true
		_show_interaction_hint()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_player_inside = false
		_hide_interaction_hint()


func _finish_dialogue() -> void:
	_release_modal_lock()
	_dialogue_open = false
	_balloon = null
	if _player_inside and _interaction_enabled:
		_show_interaction_hint()


func _acquire_modal_lock() -> void:
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)


func _release_modal_lock() -> void:
	if get_tree() != null and not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")


func _find_player_data() -> PlayerData:
	var current: Node = self
	while current != null:
		if current.has_method("get_player_data"):
			return current.call("get_player_data") as PlayerData
		current = current.get_parent()
	return null


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI


func _show_interaction_hint() -> void:
	if not _interaction_enabled:
		return
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_interaction_hint() -> void:
	if not is_inside_tree():
		return
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)


func _hint_id() -> String:
	return "enzuo_night_%s" % get_instance_id()

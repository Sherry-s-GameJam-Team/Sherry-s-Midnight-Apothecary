class_name PostmanNightNPC
extends Area2D

const ACTIVE_DAY := 3
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const INTRO_FLAG: StringName = &"special_orange_customer_intro_played"
const COMPLETED_FLAG: StringName = &"special_orange_customer_completed"

@export var dialogue_resource: Resource
@export var interaction_hint_text := "按[E]与钟庭邮差交谈"

@onready var visual: Sprite2D = get_node_or_null("Visual")

var _player_inside := false
var _dialogue_open := false
var _interaction_enabled := false
var _modal_lock_was_set := false
var _balloon: Node


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
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
	elif not _dialogue_open:
		var player_data := _find_player_data()
		if player_data != null and not player_data.has_event_flag(INTRO_FLAG) and not player_data.has_event_flag(COMPLETED_FLAG):
			call_deferred("trigger_auto_intro")


func on_level_entered(_entry_id: StringName = &"default") -> void:
	if not _interaction_enabled or _dialogue_open:
		return
	var player_data := _find_player_data()
	if player_data != null and not player_data.has_event_flag(INTRO_FLAG) and not player_data.has_event_flag(COMPLETED_FLAG):
		call_deferred("trigger_auto_intro")


func trigger_auto_intro() -> void:
	if not is_inside_tree() or not _interaction_enabled or _dialogue_open:
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		return
	var player_data := _find_player_data()
	if player_data != null and (player_data.has_event_flag(INTRO_FLAG) or player_data.has_event_flag(COMPLETED_FLAG)):
		return
	start_interaction(&"special_orange_customer")


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


func start_interaction(override_title: StringName = &"") -> void:
	var resource := _get_dialogue_resource()
	if resource == null:
		push_error("PostmanNightNPC requires a dialogue resource.")
		return
	_dialogue_open = true
	_hide_interaction_hint()
	_acquire_modal_lock()
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("PostmanNightNPC requires DialogueManager autoload.")
		_finish_dialogue()
		return
	var extra_game_states: Array = [self]
	var player_data := _find_player_data()
	if player_data != null:
		extra_game_states.append({"player_data": player_data})
	var start_title := override_title
	if start_title == &"":
		start_title = _resolve_dialogue_title()
	_balloon = dialogue_manager.show_dialogue_balloon_scene(
		BALLOON_SCENE,
		resource,
		str(start_title),
		extra_game_states
	)
	if _balloon == null:
		_finish_dialogue()
		return
	if _balloon.has_signal("dialogue_event"):
		_balloon.dialogue_event.connect(_on_dialogue_event)
	_balloon.tree_exited.connect(_finish_dialogue, CONNECT_ONE_SHOT)


func _get_dialogue_resource() -> Resource:
	if dialogue_resource != null:
		return dialogue_resource
	const PATH := "res://night/levels/home/postman_day_three.dialogue"
	if ResourceLoader.exists(PATH):
		return load(PATH)
	return null


func _resolve_dialogue_title() -> StringName:
	var player_data := _find_player_data()
	if player_data == null:
		return &"special_orange_customer"
	if player_data.has_event_flag(COMPLETED_FLAG):
		return &"postman_completed"
	if player_data.has_event_flag(INTRO_FLAG):
		return &"postman_repeat"
	return &"special_orange_customer"


func _on_dialogue_event(event_name: StringName, _payload: Variant) -> void:
	match event_name:
		&"postman_deliver_orange_potion":
			_deliver_orange_potion()


func _deliver_orange_potion() -> void:
	var player_data := _find_player_data()
	if player_data == null:
		return
	player_data.consume_potion(&"orange_potion", 1)
	player_data.set_event_flag(INTRO_FLAG)
	player_data.set_event_flag(COMPLETED_FLAG)
	player_data.set_event_flag(&"story_event_completed:special_orange_customer")
	player_data.set_event_flag(&"orange_potion_unlocked")
	player_data.set_event_flag(&"aurem_clockyard_portal_unlocked")
	player_data.set_event_flag(&"aurem_portal_key_calibrated")
	player_data.unlock_level(&"aurem_clockyard")
	player_data.unlock_potion_recipe(&"recipe_orange_activation_draft")
	player_data.unlock_codex_function(&"func_vigor_boost")
	player_data.unlock_codex_function(&"func_muscle_active")
	player_data.unlock_throwable_potion(&"orange_potion")


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
	if get_tree() != null:
		_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
		get_tree().set_meta("day_modal_input_locked", true)


func _release_modal_lock() -> void:
	if get_tree() != null and not _modal_lock_was_set and get_tree().has_meta("day_modal_input_locked"):
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
	return "postman_night_%s" % get_instance_id()

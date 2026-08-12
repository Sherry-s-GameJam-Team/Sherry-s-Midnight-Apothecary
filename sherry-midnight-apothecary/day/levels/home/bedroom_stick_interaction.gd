class_name BedroomStickInteraction
extends Sprite2D

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const READ_FLAG := "bedroom_stick_read"

@export var dialogue_resource: DialogueResource
@export var dialogue_title := "start"
@export var interaction_hint_text := "按[E]阅读便签"
@export_node_path("Area2D") var interaction_area_path := NodePath("InteractionArea")

var _player: CharacterBody2D
var _player_inside := false
var _dialogue_open := false
var _balloon: Node
var _modal_lock_was_set := false

@onready var _interaction_area: Area2D = get_node_or_null(interaction_area_path) as Area2D


func _ready() -> void:
	if _interaction_area == null:
		push_error("BedroomStickInteraction requires an interaction Area2D.")
		return
	_interaction_area.monitoring = true
	_interaction_area.body_entered.connect(_on_body_entered)
	_interaction_area.body_exited.connect(_on_body_exited)
	_update_interaction_state()


func _input(event: InputEvent) -> void:
	if _has_been_read() or _dialogue_open or not _player_inside or not _is_interact_event(event):
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
		if not _has_been_read():
			_show_interaction_hint()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_inside = false
		_hide_interaction_hint()


func _start_dialogue() -> void:
	if dialogue_resource == null:
		push_error("BedroomStickInteraction requires a dialogue resource.")
		return
	_mark_as_read()
	_dialogue_open = true
	_hide_interaction_hint()
	if _player != null:
		_player.set_physics_process(false)
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("BedroomStickInteraction requires the DialogueManager autoload.")
		_finish_dialogue()
		return
	_balloon = dialogue_manager.show_dialogue_balloon_scene(
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


func _has_been_read() -> bool:
	var player_data := _find_player_data()
	return player_data != null and bool(player_data.tutorial_flags.get(READ_FLAG, false))


func _mark_as_read() -> void:
	var player_data := _find_player_data()
	if player_data != null:
		player_data.tutorial_flags[READ_FLAG] = true
	_update_interaction_state()


func _update_interaction_state() -> void:
	if _interaction_area != null:
		_interaction_area.set_deferred("monitoring", not _has_been_read())


func _find_player_data() -> PlayerData:
	var runtime := _find_day_runtime()
	return runtime.call("get_player_data") as PlayerData if runtime != null else null


func _find_day_runtime() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data") and current.has_method("switch_to_level"):
			return current
		current = current.get_parent()
	return null


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)


func _show_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI


func _hint_id() -> String:
	return "interaction_%s" % get_instance_id()

@tool
class_name MewNPC
extends Area2D

## Interactive NPC script for Mew.
## Supports forward-and-backward (ping-pong) looping animation playback
## and E-key interactive dialogue triggering.

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const ORDER_DELIVERED_FLAG: StringName = &"mew_order_delivered"

signal dialogue_started
signal dialogue_finished
signal dialogue_event(event_name: StringName, payload: Variant)

@export_group("Dialogue")
@export var dialogue_resource: DialogueResource
@export var dialogue_title: String = "start"
@export var interaction_hint_text: String = "按[E]与喵斯交谈"
@export var interaction_enabled: bool = true
@export_node_path("TopHintUI") var hint_ui_path: NodePath

@export_group("Animation")
@export var ping_pong: bool = true
@export_range(1.0, 60.0, 0.5, "suffix: fps") var animation_fps: float = 8.0
@export var animation_name: StringName = &"fishing"
@export_node_path("AnimatedSprite2D") var sprite_path: NodePath

@onready var _sprite: AnimatedSprite2D = _resolve_sprite()

var _animation_time: float = 0.0
var _player: CharacterBody2D
var _player_inside: bool = false
var _dialogue_open: bool = false
var _balloon: Node
var _modal_lock_was_set: bool = false
var _hint_ui: TopHintUI

# Dialogue state tracking for question menu progression
var asked_mayor: bool = false
var asked_village: bool = false
var asked_father: bool = false
var asked_potion: bool = false
var intro_completed: bool = false


func _ready() -> void:
	if _sprite == null:
		_sprite = _resolve_sprite()
	if _sprite != null and _sprite.sprite_frames != null:
		_sprite.stop()
	if Engine.is_editor_hint():
		return
	_hint_ui = _find_top_hint()
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _sprite == null:
		_sprite = _resolve_sprite()
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(animation_name):
		return
	var frame_count := _sprite.sprite_frames.get_frame_count(animation_name)
	if frame_count <= 1:
		return

	if ping_pong:
		var cycle_frame_count: int = frame_count * 2 - 2
		_animation_time = fmod(_animation_time + delta * animation_fps, float(cycle_frame_count))
		var cycle_frame: int = int(_animation_time) % cycle_frame_count
		var actual_frame: int = cycle_frame if cycle_frame < frame_count else cycle_frame_count - cycle_frame
		_sprite.animation = animation_name
		_sprite.frame = actual_frame
	else:
		_animation_time = fmod(_animation_time + delta * animation_fps, float(frame_count))
		_sprite.animation = animation_name
		_sprite.frame = int(_animation_time) % frame_count


func _input(event: InputEvent) -> void:
	if not interaction_enabled or _dialogue_open or not _player_inside or not _is_interact_event(event):
		return
	if get_tree().has_meta("day_modal_input_locked"):
		return
	get_viewport().set_input_as_handled()
	_start_dialogue()


func _exit_tree() -> void:
	_hide_interaction_hint()
	if _dialogue_open:
		_finish_dialogue()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.name == "Player" or body.name.begins_with("Player") or body.is_in_group("dialogue_lockable")):
		_player = body
		_player_inside = true
		if interaction_enabled and not _dialogue_open:
			_show_interaction_hint()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_inside = false
		_hide_interaction_hint()


func _start_dialogue() -> void:
	if dialogue_resource == null:
		push_warning("MewNPC has no dialogue_resource assigned.")
		return
	_dialogue_open = true
	_hide_interaction_hint()
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("MewNPC requires DialogueManager autoload.")
		_finish_dialogue()
		return
	var extra_game_states: Array = [self]
	var player_data := _find_player_data()
	if player_data != null:
		extra_game_states.append({"player_data": player_data})
	_balloon = dialogue_manager.show_dialogue_balloon_scene(
		BALLOON_SCENE,
		dialogue_resource,
		dialogue_title,
		extra_game_states
	)
	if _balloon == null:
		_finish_dialogue()
		return
	dialogue_started.emit()
	if _balloon.has_signal("dialogue_event"):
		_balloon.connect("dialogue_event", _on_balloon_dialogue_event)
	_balloon.tree_exited.connect(_finish_dialogue, CONNECT_ONE_SHOT)


func _finish_dialogue() -> void:
	if not _dialogue_open:
		return
	_dialogue_open = false
	_balloon = null
	var player_data := _find_player_data()
	if player_data != null:
		player_data.set_event_flag(ORDER_DELIVERED_FLAG)
	if not _modal_lock_was_set and is_inside_tree() and get_tree() != null:
		get_tree().remove_meta("day_modal_input_locked")
	dialogue_finished.emit()
	if _player_inside and interaction_enabled:
		_show_interaction_hint()


func _on_balloon_dialogue_event(event_name: StringName, payload: Variant) -> void:
	dialogue_event.emit(event_name, payload)


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)


func _resolve_sprite() -> AnimatedSprite2D:
	if not sprite_path.is_empty():
		var node := get_node_or_null(sprite_path) as AnimatedSprite2D
		if node != null:
			return node
	if has_node("AnimatedSprite2D"):
		return get_node("AnimatedSprite2D") as AnimatedSprite2D
	if has_node("FishingLoop"):
		return get_node("FishingLoop") as AnimatedSprite2D
	if has_node("IdleLoop"):
		return get_node("IdleLoop") as AnimatedSprite2D
	for child in get_children():
		if child is AnimatedSprite2D:
			return child
	return null


func _show_interaction_hint() -> void:
	if not interaction_enabled:
		return
	var hint_ui := _resolve_hint_ui()
	if hint_ui != null:
		hint_ui.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_interaction_hint() -> void:
	var hint_ui := _resolve_hint_ui()
	if hint_ui != null:
		hint_ui.hide_interaction_hint(_hint_id())


func _resolve_hint_ui() -> TopHintUI:
	if is_instance_valid(_hint_ui):
		return _hint_ui
	_hint_ui = _find_top_hint()
	return _hint_ui


func _find_top_hint() -> TopHintUI:
	if not hint_ui_path.is_empty():
		var configured_hint := get_node_or_null(hint_ui_path) as TopHintUI
		if configured_hint != null:
			return configured_hint
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	if is_inside_tree():
		var tree := get_tree()
		if tree != null and tree.root != null:
			return tree.root.find_child("TopHintUI", true, false) as TopHintUI
	return null


func _find_player_data() -> PlayerData:
	var current: Node = self
	while current != null:
		if current.has_method("get_player_data"):
			return current.call("get_player_data") as PlayerData
		current = current.get_parent()
	return null


func _hint_id() -> String:
	return "interaction_%s" % get_instance_id()

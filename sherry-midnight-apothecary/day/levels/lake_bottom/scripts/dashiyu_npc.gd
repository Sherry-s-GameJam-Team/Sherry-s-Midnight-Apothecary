class_name DashiyuNPC
extends Area2D

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const SpringburstProgression := preload("res://day/levels/lake_bottom/scripts/springburst_potion_progression.gd")
const COMPLETED_FLAG := &"lake_bottom_dashiyu_dialogue_completed"
const DAY_TWO := 2

@export var dialogue_resource: DialogueResource
@export var dialogue_title := "start"
@export var interaction_hint_text := "按[E]与大司鱼交谈"
@export_node_path("CharacterBody2D") var player_path: NodePath

var _player: CharacterBody2D
var _player_near := false
var _dialogue_open := false
var _modal_lock_was_set := false
var _balloon: Node
var _camera_base_offset := Vector2.ZERO

@onready var prompt: Label = get_node_or_null("Prompt")


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	if not _should_appear():
		visible = false
		monitoring = false
		monitorable = false
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _player_near or _dialogue_open or get_tree().has_meta("day_modal_input_locked"):
		return
	if event.is_action_pressed(&"interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		get_viewport().set_input_as_handled()
		_start_dialogue()


func _exit_tree() -> void:
	_hide_interaction_hint()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body == _player or body.is_in_group("player")):
		_player_near = true
		_show_interaction_hint()


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player_near = false
		_hide_interaction_hint()


func _start_dialogue() -> void:
	if dialogue_resource == null:
		push_error("DashiyuNPC requires a dialogue resource.")
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("DashiyuNPC requires the DialogueManager autoload.")
		return
	_dialogue_open = true
	_hide_interaction_hint()
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	_balloon = dialogue_manager.show_dialogue_balloon_scene(
		BALLOON_SCENE,
		dialogue_resource,
		dialogue_title,
		[self, {"player_data": _find_player_data()}]
	)
	if _balloon == null:
		_finish_dialogue()
		return
	if _balloon.has_signal("dialogue_event"):
		_balloon.dialogue_event.connect(_on_dialogue_event)
	_balloon.tree_exited.connect(_finish_dialogue, CONNECT_ONE_SHOT)


func _on_dialogue_event(event_name: StringName, _payload: Variant) -> void:
	if event_name == &"camera_shake":
		_shake_camera()


func _finish_dialogue() -> void:
	if not _dialogue_open:
		return
	_dialogue_open = false
	_balloon = null
	if not _modal_lock_was_set and is_inside_tree():
		get_tree().remove_meta("day_modal_input_locked")
	call_deferred("_complete_and_return_to_lake")


func _complete_and_return_to_lake() -> void:
	var player_data := _find_player_data()
	if player_data != null:
		player_data.set_event_flag(COMPLETED_FLAG)
		SpringburstProgression.enforce_story_item_phase(player_data)
		if int(player_data.story_items.get(SpringburstProgression.STORY_ITEM_ID, 0)) <= 0:
			SpringburstProgression.grant_story_bottles(player_data, 4)
	var level := _find_level()
	if level != null and level.has_method("on_dashiyu_dialogue_completed"):
		level.call("on_dashiyu_dialogue_completed")
	visible = false
	monitoring = false
	monitorable = false
	var runtime := _find_day_runtime()
	if runtime != null and runtime.has_method("transition_to_level_with_blackout"):
		await runtime.transition_to_level_with_blackout("lake_bottom", &"tide_eye_arena", true)


func _shake_camera() -> void:
	if _player == null:
		return
	var camera := _player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	_camera_base_offset = camera.offset
	var tween := create_tween()
	for index in range(8):
		var strength := 10.0 * (1.0 - float(index) / 8.0)
		var offset := Vector2(sin(float(index) * 2.4), cos(float(index) * 1.7)) * strength
		tween.tween_property(camera, "offset", _camera_base_offset + offset, 0.045)
	tween.tween_property(camera, "offset", _camera_base_offset, 0.05)


func _should_appear() -> bool:
	var player_data := _find_player_data()
	return _current_day() == DAY_TWO and player_data != null and not player_data.has_event_flag(COMPLETED_FLAG)


func _current_day() -> int:
	var runtime := _find_day_runtime()
	return int(runtime.get("day")) if runtime != null else -1


func _show_interaction_hint() -> void:
	if prompt:
		prompt.visible = true
	var hint := _find_top_hint()
	if hint != null:
		hint.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_interaction_hint() -> void:
	if prompt:
		prompt.visible = false
	var hint := _find_top_hint()
	if hint != null:
		hint.hide_interaction_hint(_hint_id())


func _find_top_hint() -> TopHintUI:
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI


func _find_day_runtime() -> Node:
	var current: Node = self
	while current != null:
		if current.has_method("get_player_data") and current.has_method("switch_to_level"):
			return current
		current = current.get_parent()
	return null


func _find_level() -> Node:
	var current: Node = self
	while current != null:
		if current.has_method("on_dashiyu_dialogue_completed"):
			return current
		current = current.get_parent()
	return null


func _find_player_data() -> PlayerData:
	var runtime := _find_day_runtime()
	return runtime.call("get_player_data") as PlayerData if runtime != null else null


func _hint_id() -> String:
	return "interaction_%s" % get_instance_id()

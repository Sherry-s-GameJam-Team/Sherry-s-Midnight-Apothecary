class_name SleepingHoundNPC
extends Area2D

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

signal dialogue_event(event_name: StringName, payload: Variant)
signal purification_succeeded
signal purification_failed(reason: String)
signal purification_reloaded

@export var dialogue_resource: DialogueResource
@export var post_purification_dialogue_resource: DialogueResource
@export var dialogue_title := "start"
@export var interaction_hint_text := "按[E]与沉睡的魔犬交谈"
@export_range(1.0, 24.0, 0.5) var animation_fps := 6.0
@export_range(1, 120, 1) var animation_frame_count := 30

@onready var visual: Sprite2D = $Visual
@onready var luca_visual: AnimatedSprite2D = $LucaVisual
@onready var target_guide: SleepingHoundTargetGuide = $TargetGuide

var _animation_time := 0.0
var _player: CharacterBody2D
var _player_inside := false
var _dialogue_open := false
var _balloon: Node
var _modal_lock_was_set := false
var _interaction_enabled := true
var _purified := false
var _corrupted_dialogue_resource: DialogueResource
var _corrupted_interaction_hint := ""


func _ready() -> void:
	_corrupted_dialogue_resource = dialogue_resource
	_corrupted_interaction_hint = interaction_hint_text
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if _purified:
		return
	var cycle_frame_count: int = maxi(1, animation_frame_count * 2 - 2)
	_animation_time = fmod(_animation_time + delta, float(cycle_frame_count) / animation_fps)
	var cycle_frame: int = int(_animation_time * animation_fps) % cycle_frame_count
	visual.frame = cycle_frame if cycle_frame < animation_frame_count else cycle_frame_count - cycle_frame


func _input(event: InputEvent) -> void:
	if not _interaction_enabled or _dialogue_open or not _player_inside or not _is_interact_event(event):
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
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("SleepingHoundNPC requires the DialogueManager autoload.")
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
	if _balloon.has_signal("dialogue_event"):
		_balloon.connect("dialogue_event", _on_balloon_dialogue_event)
	_balloon.tree_exited.connect(_finish_dialogue, CONNECT_ONE_SHOT)


func _finish_dialogue() -> void:
	if not _dialogue_open:
		return
	_dialogue_open = false
	_balloon = null
	if not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")
	if _player_inside and _interaction_enabled:
		_show_interaction_hint()


func _on_balloon_dialogue_event(event_name: StringName, payload: Variant) -> void:
	dialogue_event.emit(event_name, payload)


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if enabled and _player_inside and not _dialogue_open:
		_show_interaction_hint()
	else:
		_hide_interaction_hint()


func show_target_guide(offset: Vector2, radius: float) -> void:
	if target_guide != null:
		target_guide.show_target(offset, radius)


func hide_target_guide() -> void:
	if target_guide != null:
		target_guide.hide_target()


func report_purification_success() -> void:
	set_purified_state(true)
	purification_succeeded.emit()


func set_purified_state(purified: bool) -> void:
	_purified = purified
	visual.visible = not purified
	luca_visual.visible = purified
	hide_target_guide()
	if purified:
		luca_visual.play(&"idle")
		dialogue_resource = post_purification_dialogue_resource
		interaction_hint_text = "按[E]与卢卡交谈"
	else:
		luca_visual.stop()
		visual.frame = 0
		_animation_time = 0.0
		dialogue_resource = _corrupted_dialogue_resource
		interaction_hint_text = _corrupted_interaction_hint
	if _player_inside and _interaction_enabled and not _dialogue_open:
		_show_interaction_hint()


func is_purified() -> bool:
	return _purified


func report_purification_failure(reason: String) -> void:
	purification_failed.emit(reason)


func report_purification_reloaded() -> void:
	purification_reloaded.emit()


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
	if not _interaction_enabled:
		return
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_interaction_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _find_top_hint() -> TopHintUI:
	var app_root := _find_app_root()
	var top_hint := app_root.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
	if top_hint != null:
		return top_hint
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI


func _hint_id() -> String:
	return "interaction_%s" % get_instance_id()

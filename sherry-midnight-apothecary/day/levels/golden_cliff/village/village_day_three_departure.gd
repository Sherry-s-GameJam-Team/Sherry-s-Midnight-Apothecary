class_name VillageDayThreeDeparture
extends Area2D

const REQUIRED_DAY := 3
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")

@export var dialogue_resource: DialogueResource
@export var interaction_hint_text := "按[E]前往绯红峡谷"

var _player_in_range := false
var _dialogue_open := false
var _depart_requested := false
var _modal_lock_was_set := false


func _ready() -> void:
	var active := _is_day_three()
	visible = active
	monitoring = active
	set_process_input(active)
	if not active:
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_set_day_three_world_state()


func _input(event: InputEvent) -> void:
	if not _player_in_range or _dialogue_open or get_tree().has_meta("day_modal_input_locked") or not _is_interact_event(event):
		return
	get_viewport().set_input_as_handled()
	_open_departure_dialogue()


func _open_departure_dialogue() -> void:
	if dialogue_resource == null:
		push_error("VillageDayThreeDeparture requires a dialogue resource.")
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("VillageDayThreeDeparture requires the DialogueManager autoload.")
		return
	_dialogue_open = true
	_depart_requested = false
	_hide_hint()
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	var balloon := dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue_resource, &"start") as Node
	if balloon == null:
		_finish_dialogue()
		return
	if balloon.has_signal("dialogue_event"):
		balloon.dialogue_event.connect(_on_dialogue_event)
	balloon.tree_exited.connect(_finish_dialogue, CONNECT_ONE_SHOT)


func _on_dialogue_event(event_name: StringName, _payload: Variant) -> void:
	if event_name == &"depart_for_crimson_vale":
		_depart_requested = true


func _finish_dialogue() -> void:
	if not _dialogue_open:
		return
	_dialogue_open = false
	if not _modal_lock_was_set and is_inside_tree():
		get_tree().remove_meta("day_modal_input_locked")
	if _depart_requested:
		_start_voyage()
	elif _player_in_range:
		_show_hint()


func _start_voyage() -> void:
	var runtime := _find_day_runtime()
	if runtime != null and runtime.has_method("transition_to_level_with_blackout"):
		runtime.call("transition_to_level_with_blackout", "village_red_voyage", &"default", true)


func _set_day_three_world_state() -> void:
	var village := get_parent()
	var issues := village.get_node_or_null("issues") as CanvasItem
	if issues != null:
		issues.visible = false
		issues.set_process(false)
		issues.set_process_input(false)
		if issues.has_method("_hide_delivery_hint"):
			issues.call("_hide_delivery_hint")
		if issues.has_method("_hide_rope_hint"):
			issues.call("_hide_rope_hint")
	var mew := village.get_node_or_null("CS/issue_Mews") as MewNPC
	if mew == null:
		mew = village.get_node_or_null("issues/issue_Mews") as MewNPC
	if mew == null and village != null:
		mew = village.find_child("issue_Mews", true, false) as MewNPC
	if mew != null:
		mew.set_interaction_enabled(false)
	var ropes := village.get_node_or_null("CS/rope") as CanvasItem
	if ropes != null:
		ropes.visible = false
	var saved := village.get_node_or_null("CS/saved") as CanvasItem
	if saved != null:
		saved.visible = true


func _on_body_entered(body: Node2D) -> void:
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
		hint.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_hint() -> void:
	var hint := _find_top_hint()
	if hint != null:
		hint.hide_interaction_hint(_hint_id())


func _is_day_three() -> bool:
	var runtime := _find_day_runtime()
	return runtime != null and runtime.day == REQUIRED_DAY


func _find_day_runtime() -> DayRuntime:
	var current: Node = get_parent()
	while current != null:
		if current is DayRuntime:
			return current
		current = current.get_parent()
	return null


func _find_top_hint() -> TopHintUI:
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI


func _hint_id() -> String:
	return "village_day_three_departure_%s" % get_instance_id()


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)

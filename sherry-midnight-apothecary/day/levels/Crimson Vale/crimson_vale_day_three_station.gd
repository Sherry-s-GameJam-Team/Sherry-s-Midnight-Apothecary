class_name CrimsonValeDayThreeStation
extends Area2D

## Day-three stationmaster interaction at Danfeng Post. The dialogue resource
## owns the narrative and menu; this node owns availability, HintUI, rewards,
## and the small repeatable wind-potion shop transaction.

const REQUIRED_DAY := 3
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const INTRO_COMPLETE_FLAG: StringName = &"crimson_vale_station_intro_complete"
const GATE_FOLLOWUP_FLAG: StringName = &"crimson_vale_station_gate_followup_played"
const WIND_POTION_ITEM: StringName = &"wind_potion"
const WIND_POTION_PRICE := 25

@export var dialogue_resource: DialogueResource
@export var interaction_hint_text := "按[E]与罗莎琳·凡恩交谈"

var _player_in_range := false
var _dialogue_open := false
var _modal_lock_was_set := false


func _ready() -> void:
	var active := _is_day_three()
	visible = active
	monitoring = active
	monitorable = active
	set_process_input(active)
	if not active:
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _input(event: InputEvent) -> void:
	if not _player_in_range or _dialogue_open or get_tree().has_meta("day_modal_input_locked") or not _is_interact_event(event):
		return
	get_viewport().set_input_as_handled()
	_open_dialogue()


func _exit_tree() -> void:
	_hide_hint()


func _open_dialogue() -> void:
	if dialogue_resource == null:
		push_error("CrimsonValeDayThreeStation requires a dialogue resource.")
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("CrimsonValeDayThreeStation requires the DialogueManager autoload.")
		return
	_dialogue_open = true
	_hide_hint()
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	var extra_game_states: Array = [self]
	var player_data := _get_player_data()
	if player_data != null:
		extra_game_states.append({"player_data": player_data})
	var start_title := _resolve_dialogue_title()
	var balloon := dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue_resource, start_title, extra_game_states) as Node
	if balloon == null:
		_finish_dialogue()
		return
	if balloon.has_signal("dialogue_event"):
		balloon.dialogue_event.connect(_on_dialogue_event)
	balloon.tree_exited.connect(_finish_dialogue, CONNECT_ONE_SHOT)


func _on_dialogue_event(event_name: StringName, payload: Variant) -> void:
	match event_name:
		&"crimson_station_intro_reward":
		_complete_intro()
		&"crimson_station_buy_wind_potion":
			_buy_wind_potions(maxi(int(payload), 1))
		&"crimson_station_gate_restored_followup":
			var player_data := _get_player_data()
			if player_data != null:
				player_data.set_event_flag(GATE_FOLLOWUP_FLAG)


func _complete_intro() -> void:
	var player_data := _get_player_data()
	if player_data == null or not player_data.set_event_flag(INTRO_COMPLETE_FLAG):
		return
	_grant_wind_potions(player_data, 1)
	var level := _find_level()
	if level != null:
		level.objective_updated.emit("前往枫林深处。", "寻找并净化丹心门。")


func _buy_wind_potions(amount: int) -> bool:
	var player_data := _get_player_data()
	var count := maxi(amount, 1)
	var cost := count * WIND_POTION_PRICE
	if player_data == null or player_data.money < cost:
		return false
	player_data.money -= cost
	_grant_wind_potions(player_data, count)
	return true


func _grant_wind_potions(player_data: PlayerData, amount: int) -> void:
	player_data.add_inventory_item(WIND_POTION_ITEM, amount)


func _finish_dialogue() -> void:
	if not _dialogue_open:
		return
	_dialogue_open = false
	if not _modal_lock_was_set and is_inside_tree():
		get_tree().remove_meta("day_modal_input_locked")
	if _player_in_range:
		_show_hint()


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


func _has_completed_intro() -> bool:
	var player_data := _get_player_data()
	return player_data != null and player_data.has_event_flag(INTRO_COMPLETE_FLAG)


func _resolve_dialogue_title() -> StringName:
	if not _has_completed_intro():
		return &"start"
	var level := _find_level()
	var player_data := _get_player_data()
	if level != null and level.is_gate_repaired and player_data != null and not player_data.has_event_flag(GATE_FOLLOWUP_FLAG):
		return &"after_gate_restored"
	return &"station_menu"


func _is_day_three() -> bool:
	var runtime := _find_runtime()
	return runtime != null and runtime.day == REQUIRED_DAY


func _get_player_data() -> PlayerData:
	var runtime := _find_runtime()
	return runtime.get_player_data() if runtime != null else null


func _find_runtime() -> DayRuntime:
	var current: Node = get_parent()
	while current != null:
		if current is DayRuntime:
			return current
		current = current.get_parent()
	return null


func _find_level() -> CrimsonValeLevel:
	var current: Node = get_parent()
	while current != null:
		if current is CrimsonValeLevel:
			return current
		current = current.get_parent()
	return null


func _find_top_hint() -> TopHintUI:
	return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI


func _hint_id() -> String:
	return "crimson_vale_station_%s" % get_instance_id()


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)

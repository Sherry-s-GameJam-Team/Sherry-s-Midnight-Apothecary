class_name LucaNightNPC
extends Area2D

signal intro_part1_finished
signal herb_reward_granted
signal intro_part2_finished
signal guidance_started
signal guidance_completed

const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const TARGET_HERB_ID := &"dew_flask_herb"
const REWARD_AMOUNT := 2
const ACTIVE_DAY := 0
const INTRO_COMPLETED_FLAG := "night_luca_intro_completed"
const REWARD_GRANTED_FLAG := "night_luca_dew_flask_given"

@export var dialogue_resource: DialogueResource = preload("res://night/levels/home/luca_night.dialogue")
@export var interaction_hint_text := "按[E]与卢卡交谈"
@export var guide_alchemy_hint_text := "前往左侧制药台（坩埚），按[E]开启炼药界面"
@export var reward_hint_text := "已收集露水水滴草*2"
@export_range(0.5, 4.0, 0.1) var hint_delay_seconds := 1.6
@export_node_path("Area2D") var alchemy_station_path := NodePath("../Equip")

@onready var visual: AnimatedSprite2D = $Visual
@onready var target_guide: Node2D = get_node_or_null("TargetGuide")

var _player: CharacterBody2D
var _player_inside := false
var _dialogue_open := false
var _balloon: Node
var _modal_lock_was_set := false
var _interaction_enabled := true
var _guiding_to_alchemy := false
var _alchemy_station: Area2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if visual != null:
		visual.play(&"idle")
	configure_for_day(-1)
	call_deferred("_connect_alchemy_station")


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


func _connect_alchemy_station() -> void:
	_alchemy_station = get_node_or_null(alchemy_station_path) as Area2D
	var home := _find_night_home()
	if home != null and home.has_signal("production_requested"):
		if not home.production_requested.is_connected(_on_alchemy_opened):
			home.production_requested.connect(_on_alchemy_opened)
		if not home.alchemy_requested.is_connected(_on_alchemy_opened):
			home.alchemy_requested.connect(_on_alchemy_opened)


func _input(event: InputEvent) -> void:
	if not _interaction_enabled or _dialogue_open or not _player_inside or not _is_interact_event(event):
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	start_interaction()


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


func start_interaction() -> void:
	if dialogue_resource == null:
		push_error("LucaNightNPC requires a dialogue resource.")
		return
	if is_intro_completed():
		_start_repeat_dialogue()
	else:
		_start_intro_flow()


func is_intro_completed() -> bool:
	var player_data := _find_player_data()
	return player_data != null and bool(player_data.tutorial_flags.get(INTRO_COMPLETED_FLAG, false))


func _start_intro_flow() -> void:
	_dialogue_open = true
	_hide_interaction_hint()
	_acquire_modal_lock()
	_open_balloon("intro_part1", _on_intro_part1_balloon_closed)


func _on_intro_part1_balloon_closed() -> void:
	intro_part1_finished.emit()
	_grant_herb_reward()
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.push_text(reward_hint_text, "luca_herb_reward", 3.0)

	var timer := get_tree().create_timer(hint_delay_seconds)
	await timer.timeout
	_open_balloon("intro_part2", _on_intro_part2_balloon_closed)


func _on_intro_part2_balloon_closed() -> void:
	intro_part2_finished.emit()
	var player_data := _find_player_data()
	if player_data != null:
		player_data.tutorial_flags[INTRO_COMPLETED_FLAG] = true
	_release_modal_lock()
	_dialogue_open = false
	_start_alchemy_guidance()
	if _player_inside and _interaction_enabled:
		_show_interaction_hint()


func _start_repeat_dialogue() -> void:
	_dialogue_open = true
	_hide_interaction_hint()
	_acquire_modal_lock()
	_open_balloon("repeat", _on_repeat_balloon_closed)


func _on_repeat_balloon_closed() -> void:
	_release_modal_lock()
	_dialogue_open = false
	if _player_inside and _interaction_enabled:
		_show_interaction_hint()


func _open_balloon(title: String, on_closed_callback: Callable) -> void:
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("LucaNightNPC requires DialogueManager autoload.")
		if on_closed_callback.is_valid():
			on_closed_callback.call()
		return
	var player_data := _find_player_data()
	var extra_game_states: Array = []
	if player_data != null:
		extra_game_states.append({"player_data": player_data})
	_balloon = dialogue_manager.show_dialogue_balloon_scene(
		BALLOON_SCENE,
		dialogue_resource,
		title,
		extra_game_states
	)
	if _balloon == null:
		if on_closed_callback.is_valid():
			on_closed_callback.call()
		return
	_balloon.tree_exited.connect(func() -> void:
		_balloon = null
		if on_closed_callback.is_valid():
			on_closed_callback.call()
	, CONNECT_ONE_SHOT)


func _grant_herb_reward() -> void:
	var player_data := _find_player_data()
	if player_data == null:
		return
	if not bool(player_data.tutorial_flags.get(REWARD_GRANTED_FLAG, false)):
		player_data.inventory[TARGET_HERB_ID] = int(player_data.inventory.get(TARGET_HERB_ID, 0)) + REWARD_AMOUNT
		player_data.tutorial_flags[REWARD_GRANTED_FLAG] = true
		herb_reward_granted.emit()


func _start_alchemy_guidance() -> void:
	_guiding_to_alchemy = true
	guidance_started.emit()
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint("guide_to_alchemy", guide_alchemy_hint_text)
	if _alchemy_station != null and _alchemy_station.has_method("_set_active"):
		_alchemy_station.call("_set_active", true)


func _on_alchemy_opened() -> void:
	if not _guiding_to_alchemy:
		return
	_guiding_to_alchemy = false
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint("guide_to_alchemy")
	if _alchemy_station != null and _alchemy_station.has_method("_set_active"):
		_alchemy_station.call("_set_active", false)
	guidance_completed.emit()


func _acquire_modal_lock() -> void:
	if get_tree() != null:
		_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
		get_tree().set_meta("day_modal_input_locked", true)


func _release_modal_lock() -> void:
	if get_tree() != null and not _modal_lock_was_set:
		get_tree().remove_meta("day_modal_input_locked")


func _finish_dialogue() -> void:
	_release_modal_lock()
	_dialogue_open = false
	_balloon = null


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)


func _find_player_data() -> PlayerData:
	var current: Node = self
	while current != null:
		if current.has_method("get_player_data"):
			return current.call("get_player_data") as PlayerData
		current = current.get_parent()
	return null


func _find_night_home() -> NightHome:
	var current: Node = self
	while current != null:
		if current is NightHome:
			return current as NightHome
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
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _hint_id() -> String:
	return "luca_night_%s" % get_instance_id()

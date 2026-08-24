class_name ClockmakerDayFourNPC
extends Area2D

## Day-four Clockyard guide. It owns its local patrol, vibration, proximity
## interaction and Dialogue Manager lifecycle; the level remains scene-flow only.

const REQUIRED_DAY := 4
const INTRO_COMPLETE_FLAG: StringName = &"aurem_clockmaker_intro_complete"
const BALLOON_SCENE := preload("res://night/dialogue/apothecary_balloon.tscn")
const DialoguePortraitDatabase := preload("res://night/dialogue/portrait_database.gd")

@export var portrait_texture: Texture2D
@export_file("*.dialogue") var dialogue_path := "res://day/levels/Aurem Clockyard/clockmaker_day_four.dialogue"
@export var interaction_hint_text := "按[E]与夜巡清道机·柒号交谈"
@export var patrol_radius := 300.0
@export var patrol_speed := 95.0
@export var vibration_amplitude := 3.0
@export var vibration_frequency := 38.0

@onready var presentation: Node2D = get_node_or_null("Presentation")

var _origin_x := 0.0
var _patrol_target_x := 0.0
var _pause_remaining := 0.0
var _player_in_range := false
var _dialogue_open := false
var _modal_lock_was_set := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var active := _is_day_four()
	visible = active
	monitoring = active
	monitorable = active
	set_process(active)
	set_process_input(active)
	if not active:
		return
	_origin_x = global_position.x
	_rng.randomize()
	_choose_patrol_target()
	if portrait_texture != null:
		DialoguePortraitDatabase.register_portrait("夜巡清道机·柒号", "default", portrait_texture)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if presentation != null:
		presentation.position.x = sin(Time.get_ticks_msec() * 0.001 * vibration_frequency) * vibration_amplitude
	if _dialogue_open:
		return
	if _pause_remaining > 0.0:
		_pause_remaining -= delta
		return
	var next_x := move_toward(global_position.x, _patrol_target_x, patrol_speed * delta)
	global_position.x = next_x
	if is_equal_approx(next_x, _patrol_target_x):
		_pause_remaining = _rng.randf_range(0.25, 1.1)
		_choose_patrol_target()


func _input(event: InputEvent) -> void:
	if not _player_in_range or _dialogue_open or get_tree().has_meta("day_modal_input_locked") or not _is_interact_event(event):
		return
	get_viewport().set_input_as_handled()
	_open_dialogue()


func _exit_tree() -> void:
	_hide_hint()


func _choose_patrol_target() -> void:
	_patrol_target_x = _origin_x + _rng.randf_range(-patrol_radius, patrol_radius)


func _open_dialogue() -> void:
	var dialogue_resource := load(dialogue_path) as DialogueResource
	if dialogue_resource == null:
		push_error("ClockmakerDayFourNPC requires a dialogue resource.")
		return
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager == null:
		push_error("ClockmakerDayFourNPC requires the DialogueManager autoload.")
		return
	_dialogue_open = true
	_hide_hint()
	_modal_lock_was_set = get_tree().has_meta("day_modal_input_locked")
	get_tree().set_meta("day_modal_input_locked", true)
	var balloon := dialogue_manager.show_dialogue_balloon_scene(BALLOON_SCENE, dialogue_resource, _resolve_dialogue_title()) as Node
	if balloon == null:
		_finish_dialogue()
		return
	if balloon.has_signal("dialogue_event"):
		balloon.dialogue_event.connect(_on_dialogue_event)
	balloon.tree_exited.connect(_finish_dialogue, CONNECT_ONE_SHOT)


func _on_dialogue_event(event_name: StringName, _payload: Variant) -> void:
	if event_name != &"aurem_clockmaker_intro_complete":
		return
	var runtime := _find_runtime()
	var player_data := runtime.get_player_data() if runtime != null else null
	if player_data != null:
		player_data.set_event_flag(INTRO_COMPLETE_FLAG)


func _resolve_dialogue_title() -> StringName:
	var runtime := _find_runtime()
	var player_data := runtime.get_player_data() if runtime != null else null
	return &"repeat" if player_data != null and player_data.has_event_flag(INTRO_COMPLETE_FLAG) else &"start"


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


func _is_day_four() -> bool:
	var runtime := _find_runtime()
	return runtime != null and runtime.day == REQUIRED_DAY


func _find_runtime() -> DayRuntime:
	var current: Node = get_parent()
	while current != null:
		if current is DayRuntime:
			return current
		current = current.get_parent()
	return null


func _find_top_hint() -> TopHintUI:
	var hint := get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	return hint


func _hint_id() -> String:
	return "interaction_%s" % get_instance_id()


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E)

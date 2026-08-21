class_name BedroomDayOneLuca
extends Node2D

## Day-one bedroom opening: fade in the room, have Luca walk to the bed, then
## begin the resource-driven dialogue. This node owns presentation only; the
## StoryEventRunner still owns dialogue completion and persistent rewards.

signal opening_completed

const ACTIVE_DAY := 1
const EVENT_ID: StringName = &"day_one_bedroom_luca_urgent"
const INTERACTION_KEY: StringName = &"day_one_luca_urgent"

@export var approach_x := 1040.0
@export var departure_x := 2070.0
@export_range(80.0, 800.0, 10.0, "suffix:px/s") var cinematic_walk_speed := 300.0
@export_range(0.0, 2.0, 0.05) var reveal_duration := 0.55

var _opening_active := false
var _player: CharacterBody2D
var _luca: LucaPlayer
var _fade_overlay: ColorRect


func _ready() -> void:
	_luca = get_node_or_null("Luca") as LucaPlayer
	_player = get_node_or_null("../Player") as CharacterBody2D
	_fade_overlay = get_node_or_null("../WakeReveal/FadeOverlay") as ColorRect
	if should_play_opening():
		visible = false
		_opening_active = true
		call_deferred("_play_opening")
	else:
		visible = false
		if is_day_one():
			_show_completed_day_one_bedroom()
		else:
			_start_regular_wake_presentation()


static func should_show(day: int) -> bool:
	return day == ACTIVE_DAY


func is_day_one() -> bool:
	var runtime := _find_day_runtime()
	return runtime != null and should_show(int(runtime.get("day")))


func should_play_opening() -> bool:
	var runtime := _find_day_runtime()
	return is_day_one() \
		and not bool(runtime.call("has_completed_story_event", EVENT_ID))


func is_opening_active() -> bool:
	return _opening_active


func _play_opening() -> void:
	if not is_inside_tree():
		return
	_show_bedroom()
	await _fade_in_bedroom()
	await _walk_luca_to_bed()
	_request_dialogue()


func _show_bedroom() -> void:
	visible = true
	_hide_sleep_to_wake_sprite()
	if _player != null:
		_player.visible = true
		_player.set_process(false)
		_player.set_physics_process(false)
		_player.set_process_input(false)
		_player.set_process_unhandled_input(false)
		_player.set_process_unhandled_key_input(false)
	if _luca != null:
		_luca.input_enabled = false


func _fade_in_bedroom() -> void:
	if _fade_overlay == null:
		return
	_fade_overlay.visible = true
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_overlay.color.a = 1.0
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_fade_overlay, "color:a", 0.0, reveal_duration)
	await tween.finished
	if _fade_overlay != null:
		_fade_overlay.visible = false
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _walk_luca_to_bed() -> void:
	if _luca == null:
		return
	_luca.set_movement_direction(-1.0)
	while is_instance_valid(_luca) and _luca.global_position.x > approach_x:
		await get_tree().physics_frame
	if is_instance_valid(_luca):
		_luca.global_position.x = approach_x
		_luca.stop_moving()


func _request_dialogue() -> void:
	var runtime := _find_day_runtime()
	if runtime == null or not bool(runtime.call("dispatch_story_event_interaction", INTERACTION_KEY)):
		_finish_opening()
		return
	runtime.connect(&"story_event_completed", _on_story_event_completed, CONNECT_ONE_SHOT)


func _on_story_event_completed(event_id: StringName) -> void:
	if event_id == EVENT_ID:
		_play_luca_departure()


func _play_luca_departure() -> void:
	if _luca == null:
		_finish_opening()
		return
	var sprite := _luca.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		# Luca's source frames face left, so walking out through the right door
		# uses the horizontally flipped run cycle.
		sprite.flip_h = true
		sprite.play(LucaPlayer.RUN_LOOP_ANIMATION)
	var duration := absf(departure_x - _luca.position.x) / cinematic_walk_speed
	var tween := create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(_luca, "position:x", departure_x, duration)
	tween.tween_callback(_finish_luca_departure)


func _finish_luca_departure() -> void:
	if _luca != null:
		_luca.stop_moving()
		_luca.visible = false
	_finish_opening()


func _finish_opening() -> void:
	if not _opening_active:
		return
	_opening_active = false
	if _player != null:
		_player.set_process(true)
		_player.set_physics_process(true)
		_player.set_process_input(true)
		_player.set_process_unhandled_input(true)
		_player.set_process_unhandled_key_input(true)
	opening_completed.emit()


func _show_completed_day_one_bedroom() -> void:
	_hide_sleep_to_wake_sprite()
	if _player != null:
		_player.visible = true
	if _fade_overlay != null:
		_fade_overlay.visible = false
		_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _start_regular_wake_presentation() -> void:
	var wake_executor := get_node_or_null("../SleepToWakeExecutor") as AnimationPresentationExecutor
	if wake_executor != null:
		wake_executor.start()


func _hide_sleep_to_wake_sprite() -> void:
	var sleep_to_wake := get_node_or_null("../SleepToWake") as AnimatedSprite2D
	if sleep_to_wake != null:
		sleep_to_wake.hide()
		sleep_to_wake.stop()


func _find_day_runtime() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data") and current.has_method("switch_to_level"):
			return current
		current = current.get_parent()
	return null

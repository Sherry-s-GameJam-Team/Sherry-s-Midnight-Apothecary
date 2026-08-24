class_name ForestEnzuoSavedInteraction
extends Node2D

## Boss completion reveals Enzuo and immediately starts the resolution event.
## The event callback owns the final fade into the night runtime.

const ACTIVE_DAY := 1
const FOREST_COMPLETED_FLAG: StringName = &"forest_completed"
const SOLVED_FLAG: StringName = &"save_enzuo_solved"
const EVENT_ID: StringName = &"day_one_forest_enzuo_saved"
const INTERACTION_KEY: StringName = &"day_one_forest_enzuo_saved"

@export_node_path("CharacterBody2D") var player_path: NodePath
@export_node_path("Node2D") var enzuo_path: NodePath
@export_node_path("ColorRect") var fade_overlay_path: NodePath

var _player: CharacterBody2D
var _enzuo: Node2D
var _fade_overlay: ColorRect
var _runtime: Node
var _starting := false


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_enzuo = get_node_or_null(enzuo_path) as Node2D
	_fade_overlay = get_node_or_null(fade_overlay_path) as ColorRect
	_resolve_runtime()
	visible = should_show(_current_day(), _player_data())
	if _runtime != null:
		_runtime.connect(&"story_event_completed", _on_story_event_completed)
	if visible:
		call_deferred("_start_resolution")


func _process(_delta: float) -> void:
	if not should_show(_current_day(), _player_data()):
		visible = false
		return
	visible = true
	if not _starting:
		_start_resolution()


func _start_resolution() -> void:
	if _starting or not should_show(_current_day(), _player_data()):
		return
	if _runtime == null or not bool(_runtime.call("dispatch_story_event_interaction", INTERACTION_KEY)):
		return
	_starting = true


static func should_show(day: int, player_data: PlayerData) -> bool:
	return day == ACTIVE_DAY and player_data != null \
		and bool(player_data.tutorial_flags.get(FOREST_COMPLETED_FLAG, false)) \
		and not player_data.has_event_flag(SOLVED_FLAG)


func _on_story_event_completed(event_id: StringName) -> void:
	if event_id == EVENT_ID:
		visible = false
		await _fade_to_black()
		_finish_day()


func _fade_to_black() -> void:
	if _fade_overlay == null:
		return
	get_tree().set_meta("day_modal_input_locked", true)
	_fade_overlay.visible = true
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_overlay.color.a = 0.0
	var tween := create_tween()
	tween.tween_property(_fade_overlay, "color:a", 1.0, 0.35)
	await tween.finished


func _finish_day() -> void:
	if _runtime == null or not _runtime.has_method("finish_day"):
		return
	var result := DayResult.new()
	result.completed = true
	var data := _player_data()
	if data != null:
		result.remaining_health = data.health
	_runtime.call("finish_day", result)


func _current_day() -> int:
	return int(_runtime.get("day")) if _runtime != null else -1


func _player_data() -> PlayerData:
	return _runtime.call("get_player_data") as PlayerData if _runtime != null else null


func _resolve_runtime() -> void:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data") and current.has_method("switch_to_level"):
			_runtime = current
			return
		current = current.get_parent()

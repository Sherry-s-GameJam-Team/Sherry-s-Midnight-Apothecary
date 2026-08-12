class_name GameFlow
extends Node

signal mode_changed(mode: Mode, day: int)
signal save_requested(day: int, mode: Mode)
signal sleep_transition_requested(result: NightResult)

enum Mode {
	DAY,
	NIGHT,
	ENDING,
}

const FINAL_DAY := 30
const DAY_SCENE := preload("res://day/day_runtime.tscn")
const NIGHT_SCENE := preload("res://night/night_runtime.tscn")

var current_day := 1
var current_mode := Mode.DAY
var current_runtime: Node
var player_data: PlayerData

var _runtime_slot: Node
var _switching := false


func configure(runtime_slot: Node, shared_player_data: PlayerData) -> void:
	_runtime_slot = runtime_slot
	player_data = shared_player_data


func start_new_game(
	initial_day_level_id: StringName = &"",
	defer_day_presentation := false,
	defer_day_title := false
) -> bool:
	if _switching or _runtime_slot == null or player_data == null:
		return false
	shutdown()
	player_data.reset()
	current_day = 1
	return _load_mode(Mode.DAY, initial_day_level_id, defer_day_presentation, defer_day_title)


func resume_game(
	day: int,
	mode: Mode,
	initial_day_level_id: StringName = &"",
	defer_day_presentation := false,
	defer_day_title := false
) -> bool:
	if _switching or _runtime_slot == null or player_data == null:
		return false
	if not Mode.values().has(int(mode)):
		return false
	shutdown()
	current_day = clampi(day, 1, FINAL_DAY)
	return _load_mode(mode, initial_day_level_id, defer_day_presentation, defer_day_title)


func complete_day(result: DayResult) -> bool:
	if current_mode != Mode.DAY or _switching or result == null:
		return false
	player_data.apply_day_result(result)
	return _load_mode(Mode.NIGHT)


func complete_night(result: NightResult) -> bool:
	return _complete_night(result, &"")


func complete_night_to_bedroom(result: NightResult) -> bool:
	return _complete_night(result, &"bedroom")


func debug_switch_mode(mode: Mode) -> bool:
	if mode == Mode.ENDING:
		return false
	var initial_day_level_id: StringName = &"bedroom" if mode == Mode.DAY else &""
	return _load_mode(mode, initial_day_level_id)


func _complete_night(result: NightResult, next_day_level_id: StringName) -> bool:
	if current_mode != Mode.NIGHT or _switching or result == null:
		return false
	player_data.apply_night_result(result)
	var changed: bool
	if current_day >= FINAL_DAY:
		changed = _load_mode(Mode.ENDING)
	else:
		current_day += 1
		changed = _load_mode(Mode.DAY, next_day_level_id)
	if changed:
		save_requested.emit(current_day, current_mode)
	return changed


func shutdown() -> void:
	if is_instance_valid(current_runtime):
		current_runtime.queue_free()
	current_runtime = null


func _load_mode(
	mode: Mode,
	initial_day_level_id: StringName = &"",
	defer_day_presentation := false,
	defer_day_title := false
) -> bool:
	if _switching or current_mode == mode and is_instance_valid(current_runtime):
		return false
	_switching = true
	if is_instance_valid(current_runtime):
		# Completion signals are handled synchronously. queue_free() is required
		# here because the runtime can still be locked while emitting `finished`.
		current_runtime.queue_free()
	current_runtime = null
	current_mode = mode
	if mode != Mode.DAY and is_inside_tree():
		var sound_manager := get_node_or_null("/root/SoundManager")
		if sound_manager != null:
			sound_manager.call("stop_bgm")

	if mode != Mode.ENDING:
		var scene: PackedScene = DAY_SCENE if mode == Mode.DAY else NIGHT_SCENE
		current_runtime = scene.instantiate()
		if mode == Mode.DAY:
			current_runtime.configure(
				player_data,
				current_day,
				initial_day_level_id,
				defer_day_presentation,
				defer_day_title
			)
			_runtime_slot.add_child(current_runtime)
		else:
			_runtime_slot.add_child(current_runtime)
			current_runtime.configure(player_data, current_day)
		if mode == Mode.DAY:
			current_runtime.finished.connect(complete_day)
		else:
			current_runtime.finished.connect(complete_night)
			current_runtime.sleep_requested.connect(_on_sleep_requested)

	_switching = false
	mode_changed.emit(current_mode, current_day)
	return true


func _on_sleep_requested(result: NightResult) -> void:
	if current_mode == Mode.NIGHT and not _switching and result != null:
		sleep_transition_requested.emit(result)

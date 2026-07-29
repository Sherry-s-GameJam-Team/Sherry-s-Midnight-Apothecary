class_name GameFlow
extends Node

signal phase_changed(previous_phase: Phase, current_phase: Phase)
signal transition_rejected(from_phase: Phase, requested_phase: Phase)
signal save_requested(save_data: Dictionary)

enum Phase {
	NONE,
	MAIN_MENU,
	DAY_INTRO,
	DAY_PREPARATION,
	DAY_LEVEL,
	DAY_RESULT,
	NIGHT_SHOP,
	NIGHT_RESULT,
	STORY_EVENT,
	ENDING,
}

const FINAL_DAY := 30
const PHASE_SEQUENCE: Dictionary = {
	Phase.MAIN_MENU: Phase.DAY_INTRO,
	Phase.DAY_INTRO: Phase.DAY_PREPARATION,
	Phase.DAY_PREPARATION: Phase.DAY_LEVEL,
	Phase.DAY_LEVEL: Phase.DAY_RESULT,
	Phase.DAY_RESULT: Phase.NIGHT_SHOP,
	Phase.NIGHT_SHOP: Phase.NIGHT_RESULT,
	Phase.NIGHT_RESULT: Phase.STORY_EVENT,
}

var session: GameSession
var scene_flow: SceneFlow
var _transition_in_progress := false


func configure(game_session: GameSession, mode_loader: SceneFlow = null) -> void:
	session = game_session
	scene_flow = mode_loader


func start_new_game() -> bool:
	if session == null:
		return false
	session._set_current_day_from_flow(1)
	session.current_phase = Phase.NONE
	return enter_phase(Phase.MAIN_MENU)


func resume_from_session() -> bool:
	if session == null:
		return false
	return Phase.values().has(session.current_phase)


func enter_phase(next_phase: Phase) -> bool:
	if session == null or _transition_in_progress:
		return false
	var previous := current_phase()
	if previous == next_phase:
		transition_rejected.emit(previous, next_phase)
		return false
	if not _is_legal_transition(previous, next_phase):
		transition_rejected.emit(previous, next_phase)
		return false

	_transition_in_progress = true
	session.current_phase = next_phase
	_transition_in_progress = false
	phase_changed.emit(previous, next_phase)
	return true


func advance_phase() -> bool:
	var phase := current_phase()
	if phase == Phase.STORY_EVENT:
		if session.current_day >= FINAL_DAY:
			return enter_phase(Phase.ENDING)
		session._set_current_day_from_flow(session.current_day + 1)
		return enter_phase(Phase.DAY_INTRO)
	if not PHASE_SEQUENCE.has(phase):
		return false
	return enter_phase(PHASE_SEQUENCE[phase] as Phase)


func submit_level_result(result: LevelResult) -> bool:
	if current_phase() != Phase.DAY_LEVEL or result == null:
		return false
	_apply_level_result(result.duplicate_result())
	return enter_phase(Phase.DAY_RESULT)


func submit_shop_result(result: ShopResult) -> bool:
	if current_phase() != Phase.NIGHT_SHOP or result == null:
		return false
	_apply_shop_result(result.duplicate_result())
	var changed := enter_phase(Phase.NIGHT_RESULT)
	if changed:
		save_requested.emit(session.to_save_data())
	return changed


func current_phase() -> Phase:
	if session == null:
		return Phase.NONE
	return session.current_phase as Phase


func is_transitioning() -> bool:
	return _transition_in_progress


func _is_legal_transition(from_phase: Phase, to_phase: Phase) -> bool:
	if from_phase == Phase.NONE:
		return to_phase == Phase.MAIN_MENU
	if from_phase == Phase.STORY_EVENT:
		if session.current_day >= FINAL_DAY:
			return to_phase == Phase.ENDING
		return to_phase == Phase.DAY_INTRO
	return PHASE_SEQUENCE.get(from_phase, Phase.NONE) == to_phase


func _apply_level_result(result: LevelResult) -> void:
	_merge_counts(session.inventory, result.collected_items)
	session.owned_potions = result.remaining_potions.duplicate(true)
	_append_unique(session.completed_puzzles, result.completed_puzzles)
	_append_unique(session.story_flags, result.story_flags)
	if result.completed and not result.level_id.is_empty():
		_append_unique(session.unlocked_levels, [result.level_id])
	if result.portal_repaired and not result.level_id.is_empty():
		_append_unique(session.repaired_portals, [result.level_id])


func _apply_shop_result(result: ShopResult) -> void:
	session.money += result.earned_money
	_subtract_counts(session.inventory, result.spent_ingredients)
	_merge_counts(session.owned_potions, result.produced_potions)
	_subtract_counts(session.owned_potions, result.sold_potions)
	for customer_id: Variant in result.customer_results:
		session.customer_relationships[customer_id] = result.customer_results[customer_id]
	_append_unique(session.story_flags, result.story_flags)


func _merge_counts(target: Dictionary, additions: Dictionary) -> void:
	for stable_id: Variant in additions:
		target[stable_id] = int(target.get(stable_id, 0)) + int(additions[stable_id])


func _subtract_counts(target: Dictionary, removals: Dictionary) -> void:
	for stable_id: Variant in removals:
		var remaining := maxi(int(target.get(stable_id, 0)) - int(removals[stable_id]), 0)
		if remaining == 0:
			target.erase(stable_id)
		else:
			target[stable_id] = remaining


func _append_unique(target: Array[StringName], values: Array[StringName]) -> void:
	for value: StringName in values:
		if not target.has(value):
			target.append(value)


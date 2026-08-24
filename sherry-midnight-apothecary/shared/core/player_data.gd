class_name PlayerData
extends Resource

signal health_changed(current_health: int, maximum_health: int)
signal health_depleted

const SAVE_VERSION := 13
const DEFAULT_POTION_SLOT_COUNT := 3
const MAX_POTION_SLOT_COUNT := 8
const DEFAULT_EQUIPPED_POTIONS: Array[StringName] = [&"", &"", &""]
const DEFAULT_CODEX_FUNCTION_IDS: Array[StringName] = [&"func_hemostasis", &"func_tissue_repair", &"func_cooling"]
const DEFAULT_CODEX_RECIPE_IDS: Array[StringName] = [&"recipe_blood_stop_paste", &"recipe_moss_balm"]
const DEFAULT_CODEX_MATRIX_CELLS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(3, 0)]
const BASE_RECIPE_BY_POTION: Dictionary = {
	&"red_potion": &"recipe_red_pressure_pulse",
	&"orange_potion": &"recipe_orange_activation_draft",
	&"yellow_potion": &"recipe_yellow_impact_buffer",
	&"green_potion": &"recipe_green_regrowth_tonic",
	&"cyan_potion": &"recipe_cyan_springburst",
	&"blue_potion": &"recipe_blue_cleanse",
	&"purple_potion": &"recipe_purple_calm_mist",
	&"purification_potion": &"recipe_purification_dew",
}

var max_health := 100
var health := 100
var money := 0
var debt := 30000
var store_reputation := 100
var inventory: Dictionary = {}
var story_items: Dictionary = {}
var potions: Dictionary = {}
var potion_slot_count := DEFAULT_POTION_SLOT_COUNT
var equipped_potion_ids: Array[StringName] = DEFAULT_EQUIPPED_POTIONS.duplicate()
var selected_potion_slot := 0
var potion_throw_orders: Dictionary = {}
var codex_unlocked_function_ids: Array[StringName] = DEFAULT_CODEX_FUNCTION_IDS.duplicate()
var codex_unlocked_recipe_ids: Array[StringName] = DEFAULT_CODEX_RECIPE_IDS.duplicate()
var codex_unlocked_matrix_cells: Array[Vector2i] = DEFAULT_CODEX_MATRIX_CELLS.duplicate()
var throwable_potion_ids: Array[StringName] = []
var upgrades: Array[StringName] = []
var unlocked_levels: Array[StringName] = [&"market", &"grassland"]
## The destination selected at Home's Transformer. The exterior door consumes it.
var active_home_destination_id: StringName = &"market"
var tutorial_flags: Dictionary = {}
var customer_states: Dictionary = {}
## Persistent narrative state owned by the resource-driven story event system.
var event_flags: Dictionary = {}
## The task card shown for the active day. It intentionally expires when the
## caller asks for a different day rather than accumulating in the journal.
var active_daily_task: Dictionary = {}


func reset() -> void:
	max_health = 100
	health = max_health
	money = 0
	debt = 30000
	store_reputation = 100
	inventory = {}
	story_items = {}
	potions = {}
	potion_slot_count = DEFAULT_POTION_SLOT_COUNT
	equipped_potion_ids = DEFAULT_EQUIPPED_POTIONS.duplicate()
	selected_potion_slot = 0
	potion_throw_orders = {}
	codex_unlocked_function_ids = DEFAULT_CODEX_FUNCTION_IDS.duplicate()
	codex_unlocked_recipe_ids = DEFAULT_CODEX_RECIPE_IDS.duplicate()
	codex_unlocked_matrix_cells = DEFAULT_CODEX_MATRIX_CELLS.duplicate()
	throwable_potion_ids = []
	upgrades = []
	unlocked_levels = [&"market", &"grassland"]
	active_home_destination_id = &"market"
	tutorial_flags = {}
	customer_states = {}
	event_flags = {}
	active_daily_task = {}
	health_changed.emit(health, max_health)


func apply_day_result(result: DayResult) -> void:
	set_health(result.remaining_health)
	_add_counts(inventory, result.collected_items)
	potions = _normalize_potions(result.remaining_potions)
	_cleanup_potion_configuration()
	unlock_level(result.unlocked_level_id)


func apply_damage(amount: int) -> int:
	if amount <= 0:
		return 0
	var previous_health := health
	set_health(health - amount)
	return previous_health - health


func restore_health(amount: int) -> int:
	if amount <= 0:
		return 0
	var previous_health := health
	set_health(health + amount)
	return health - previous_health


func restore_full_health() -> void:
	set_health(max_health)


func set_health(value: int) -> void:
	var previous_health := health
	health = clampi(value, 0, maxi(max_health, 1))
	if health == previous_health:
		return
	health_changed.emit(health, max_health)
	if health == 0 and previous_health > 0:
		health_depleted.emit()


func set_max_health(value: int) -> void:
	var previous_maximum := max_health
	var previous_health := health
	max_health = maxi(value, 1)
	health = clampi(health, 0, max_health)
	if max_health != previous_maximum or health != previous_health:
		health_changed.emit(health, max_health)
		if health == 0 and previous_health > 0:
			health_depleted.emit()


func restore_from_save_data(data: Dictionary) -> void:
	var restored := PlayerData.from_save_data(data)
	max_health = restored.max_health
	health = restored.health
	money = restored.money
	debt = restored.debt
	store_reputation = restored.store_reputation
	inventory = restored.inventory.duplicate(true)
	story_items = restored.story_items.duplicate(true)
	potions = restored.potions.duplicate(true)
	potion_slot_count = restored.potion_slot_count
	equipped_potion_ids = restored.equipped_potion_ids.duplicate()
	selected_potion_slot = restored.selected_potion_slot
	potion_throw_orders = restored.potion_throw_orders.duplicate(true)
	codex_unlocked_function_ids = restored.codex_unlocked_function_ids.duplicate()
	codex_unlocked_recipe_ids = restored.codex_unlocked_recipe_ids.duplicate()
	codex_unlocked_matrix_cells = restored.codex_unlocked_matrix_cells.duplicate()
	throwable_potion_ids = restored.throwable_potion_ids.duplicate()
	upgrades = restored.upgrades.duplicate()
	unlocked_levels = restored.unlocked_levels.duplicate()
	active_home_destination_id = restored.active_home_destination_id
	tutorial_flags = restored.tutorial_flags.duplicate(true)
	customer_states = restored.customer_states.duplicate(true)
	event_flags = restored.event_flags.duplicate(true)
	active_daily_task = restored.active_daily_task.duplicate(true)
	health_changed.emit(health, max_health)


func has_unlocked_level(level_id: StringName) -> bool:
	return level_id != &"" and unlocked_levels.has(level_id)


func unlock_level(level_id: StringName) -> bool:
	if level_id == &"" or unlocked_levels.has(level_id):
		return false
	unlocked_levels.append(level_id)
	return true


func set_active_home_destination(level_id: StringName) -> bool:
	if not has_unlocked_level(level_id):
		return false
	active_home_destination_id = level_id
	return true


func has_event_flag(flag_id: StringName) -> bool:
	return flag_id != &"" and bool(event_flags.get(str(flag_id), false))


func set_event_flag(flag_id: StringName) -> bool:
	if flag_id == &"" or has_event_flag(flag_id):
		return false
	event_flags[str(flag_id)] = true
	return true


func clear_event_flag(flag_id: StringName) -> bool:
	if flag_id == &"" or not event_flags.has(str(flag_id)):
		return false
	event_flags.erase(str(flag_id))
	return true


func add_inventory_item(item_id: StringName, amount: int = 1) -> void:
	if item_id == &"" or amount <= 0:
		return
	inventory[item_id] = int(inventory.get(item_id, 0)) + amount


func set_active_daily_task(task_id: StringName, task_title: String, task_day: int) -> bool:
	if task_id == &"" or task_day < 0:
		return false
	var normalized_title: String = task_title.strip_edges()
	active_daily_task = {
		"day": task_day,
		"id": str(task_id),
		"title": normalized_title,
	}
	return true


func get_active_daily_task(current_day: int) -> Dictionary:
	if int(active_daily_task.get("day", -1)) != current_day:
		return {}
	return active_daily_task.duplicate(true)


func apply_night_result(result: NightResult) -> void:
	money += result.earned_money
	store_reputation = clampi(store_reputation + result.reputation_delta, 0, 100)
	_subtract_counts(inventory, result.spent_ingredients)
	_append_potions(potions, result.produced_potions)
	for potion_key: Variant in result.produced_potions:
		_register_brewed_potion_type(StringName(str(potion_key)))
	_remove_potions(potions, result.sold_potions)
	_cleanup_potion_configuration()


func add_brewed_potion(instance: Dictionary) -> void:
	var potion_id := StringName(str(instance.get("potion_id", "")))
	var uid := str(instance.get("instance_uid", ""))
	if potion_id == &"" or uid.is_empty():
		return
	var existing := _potion_array(potion_id, potions.get(potion_id, []))
	if existing.any(func(item: Dictionary) -> bool: return str(item.get("instance_uid", "")) == uid):
		return
	for normalized: Dictionary in _potion_array(potion_id, [instance]):
		existing.append(normalized)
	potions[potion_id] = existing
	_rebuild_default_throw_order(potion_id)
	_register_brewed_potion_type(potion_id)


func to_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"max_health": max_health,
		"health": health,
		"money": money,
		"debt": debt,
		"store_reputation": store_reputation,
		"inventory": _serialize_counts(inventory),
		"story_items": _serialize_counts(story_items),
		"potions": _serialize_potions(potions),
		"potion_slot_count": potion_slot_count,
		"equipped_potion_ids": equipped_potion_ids.map(func(value: StringName) -> String: return str(value)),
		"selected_potion_slot": selected_potion_slot,
		"potion_throw_orders": _serialize_throw_orders(potion_throw_orders),
		"codex_unlocked_function_ids": codex_unlocked_function_ids.map(func(value: StringName) -> String: return str(value)),
		"codex_unlocked_recipe_ids": codex_unlocked_recipe_ids.map(func(value: StringName) -> String: return str(value)),
		"codex_unlocked_matrix_cells": codex_unlocked_matrix_cells.map(func(value: Vector2i) -> Array: return [value.x, value.y]),
		"throwable_potion_ids": throwable_potion_ids.map(func(value: StringName) -> String: return str(value)),
		"upgrades": upgrades.map(func(value: StringName) -> String: return str(value)),
		"unlocked_levels": unlocked_levels.map(func(value: StringName) -> String: return str(value)),
		"active_home_destination_id": str(active_home_destination_id),
		"tutorial_flags": tutorial_flags.duplicate(),
		"customer_states": customer_states.duplicate(true),
		"event_flags": event_flags.duplicate(),
		"active_daily_task": active_daily_task.duplicate(true),
	}


static func from_save_data(data: Dictionary) -> PlayerData:
	var result := PlayerData.new()
	result.max_health = maxi(int(data.get("max_health", 100)), 1)
	result.health = clampi(int(data.get("health", result.max_health)), 0, result.max_health)
	result.money = int(data.get("money", 0))
	var saved_version := int(data.get("version", 0))
	result.debt = int(data.get("debt", 30000)) if saved_version >= 7 else 30000
	result.store_reputation = clampi(int(data.get("store_reputation", 100)), 0, 100) if saved_version >= 7 else 100
	result.inventory = _count_dictionary(data.get("inventory", {}))
	result.story_items = _count_dictionary(data.get("story_items", {}))
	result.potions = _normalize_potions(data.get("potions", {}))
	result.potion_slot_count = clampi(int(data.get("potion_slot_count", DEFAULT_POTION_SLOT_COUNT)), DEFAULT_POTION_SLOT_COUNT, MAX_POTION_SLOT_COUNT)
	result.equipped_potion_ids = _string_name_array(data.get("equipped_potion_ids", DEFAULT_EQUIPPED_POTIONS))
	result.selected_potion_slot = clampi(int(data.get("selected_potion_slot", 0)), 0, result.potion_slot_count - 1)
	result.potion_throw_orders = _normalize_throw_orders(data.get("potion_throw_orders", {}))
	result.codex_unlocked_function_ids = _string_name_array(data.get("codex_unlocked_function_ids", DEFAULT_CODEX_FUNCTION_IDS))
	result.codex_unlocked_recipe_ids = _string_name_array(data.get("codex_unlocked_recipe_ids", DEFAULT_CODEX_RECIPE_IDS))
	result.codex_unlocked_matrix_cells = _vector2i_array(data.get("codex_unlocked_matrix_cells", DEFAULT_CODEX_MATRIX_CELLS))
	result.throwable_potion_ids = _string_name_array(data.get("throwable_potion_ids", []))
	result.upgrades = _string_name_array(data.get("upgrades", []))
	result.unlocked_levels = _string_name_array(data.get("unlocked_levels", [&"market", &"grassland"]))
	if result.unlocked_levels.is_empty():
		result.unlocked_levels = [&"market", &"grassland"]
	elif saved_version < SAVE_VERSION and not result.unlocked_levels.has(&"grassland"):
		result.unlocked_levels.append(&"grassland")
	var saved_destination := StringName(str(data.get("active_home_destination_id", &"market")))
	result.active_home_destination_id = saved_destination if result.has_unlocked_level(saved_destination) else result.unlocked_levels[0]
	result.tutorial_flags = _bool_dictionary(data.get("tutorial_flags", {}))
	result.customer_states = _customer_state_dictionary(data.get("customer_states", {}))
	result.event_flags = _bool_dictionary(data.get("event_flags", {}))
	result.active_daily_task = _daily_task_dictionary(data.get("active_daily_task", {}))
	if saved_version < SAVE_VERSION:
		result._migrate_legacy_potion_unlocks()
	result._cleanup_potion_configuration()
	return result


func unlock_potion_slot(amount: int = 1) -> void:
	potion_slot_count = clampi(potion_slot_count + maxi(amount, 0), DEFAULT_POTION_SLOT_COUNT, MAX_POTION_SLOT_COUNT)
	while equipped_potion_ids.size() < potion_slot_count:
		equipped_potion_ids.append(&"")


func equip_potion(slot_index: int, potion_id: StringName) -> bool:
	if slot_index < 0 or slot_index >= potion_slot_count or potion_id == &"" or potion_id == &"black_potion" or not is_potion_throwable_unlocked(potion_id):
		return false
	for index in range(equipped_potion_ids.size()):
		if index != slot_index and equipped_potion_ids[index] == potion_id:
			return false
	while equipped_potion_ids.size() < potion_slot_count:
		equipped_potion_ids.append(&"")
	equipped_potion_ids[slot_index] = potion_id
	return true


func move_equip_potion(slot_index: int, potion_id: StringName) -> bool:
	if slot_index < 0 or slot_index >= potion_slot_count or potion_id == &"" or potion_id == &"black_potion" or not is_potion_throwable_unlocked(potion_id):
		return false
	while equipped_potion_ids.size() < potion_slot_count:
		equipped_potion_ids.append(&"")
	for index in range(equipped_potion_ids.size()):
		if index != slot_index and equipped_potion_ids[index] == potion_id:
			equipped_potion_ids[index] = &""
	equipped_potion_ids[slot_index] = potion_id
	return true


func unequip_potion(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < equipped_potion_ids.size():
		equipped_potion_ids[slot_index] = &""


func select_potion_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < potion_slot_count:
		selected_potion_slot = slot_index


func unlock_potion_recipe(recipe_id: StringName) -> bool:
	if recipe_id == &"" or codex_unlocked_recipe_ids.has(recipe_id):
		return false
	codex_unlocked_recipe_ids.append(recipe_id)
	return true


func unlock_codex_function(function_id: StringName) -> bool:
	if function_id == &"" or codex_unlocked_function_ids.has(function_id):
		return false
	codex_unlocked_function_ids.append(function_id)
	return true


func unlock_codex_matrix_cell(cell: Vector2i) -> bool:
	if codex_unlocked_matrix_cells.has(cell):
		return false
	codex_unlocked_matrix_cells.append(cell)
	return true


func unlock_throwable_potion(potion_id: StringName) -> bool:
	if potion_id == &"" or potion_id == &"black_potion" or throwable_potion_ids.has(potion_id):
		return false
	throwable_potion_ids.append(potion_id)
	return true


func is_potion_recipe_unlocked(recipe_id: StringName) -> bool:
	return recipe_id != &"" and codex_unlocked_recipe_ids.has(recipe_id)


func is_potion_throwable_unlocked(potion_id: StringName) -> bool:
	return potion_id != &"" and throwable_potion_ids.has(potion_id)


func _register_brewed_potion_type(potion_id: StringName) -> void:
	var recipe_id: StringName = BASE_RECIPE_BY_POTION.get(potion_id, &"")
	if recipe_id != &"":
		unlock_potion_recipe(recipe_id)
	if potion_id != &"cyan_potion" or has_event_flag(&"springburst_throwable_unlocked"):
		unlock_throwable_potion(potion_id)


## Dialogue Manager game-state query: number of non-empty bottles owned.
## Pass PlayerData in extra_game_states, then use:
## if potion_count("yellow_potion") >= 1
func potion_count(potion_id: StringName) -> int:
	var count := 0
	var stored_instances: Variant = potions.get(potion_id, [])
	if stored_instances is not Array:
		return count
	for value: Variant in stored_instances:
		if value is Dictionary and float((value as Dictionary).get("remaining_dose", 1.0)) > 0.0001:
			count += 1
	return count


## Dialogue Manager game-state query: total liquid remaining across all bottles.
func potion_dose(potion_id: StringName) -> float:
	var total := 0.0
	var stored_instances: Variant = potions.get(potion_id, [])
	if stored_instances is not Array:
		return total
	for value: Variant in stored_instances:
		if value is Dictionary:
			total += clampf(float((value as Dictionary).get("remaining_dose", 1.0)), 0.0, 1.0)
	return total


## Dialogue Manager game-state query: whether at least the requested bottle count is owned.
func has_potion(potion_id: StringName, minimum_count: int = 1) -> bool:
	return potion_count(potion_id) >= maxi(minimum_count, 0)


## Consumes the specified number of potion bottles from inventory.
func consume_potion(potion_id: StringName, amount: int = 1) -> bool:
	if potion_count(potion_id) < amount:
		return false
	_remove_potions(potions, {potion_id: amount})
	_cleanup_potion_configuration()
	return true


func add_story_item(item_id: StringName, amount: int = 1) -> void:
	if item_id == &"" or amount <= 0:
		return
	story_items[item_id] = int(story_items.get(item_id, 0)) + amount


func remove_story_item(item_id: StringName, amount: int = 1) -> void:
	if item_id == &"" or amount <= 0:
		return
	var remaining := maxi(int(story_items.get(item_id, 0)) - amount, 0)
	if remaining == 0:
		story_items.erase(item_id)
	else:
		story_items[item_id] = remaining


func _add_counts(target: Dictionary, additions: Dictionary) -> void:
	for stable_id: Variant in additions:
		target[stable_id] = int(target.get(stable_id, 0)) + int(additions[stable_id])


func _subtract_counts(target: Dictionary, removals: Dictionary) -> void:
	for stable_id: Variant in removals:
		var remaining := maxi(int(target.get(stable_id, 0)) - int(removals[stable_id]), 0)
		if remaining == 0:
			target.erase(stable_id)
		else:
			target[stable_id] = remaining


func _append_potions(target: Dictionary, additions: Dictionary) -> void:
	for potion_key: Variant in additions:
		var potion_id := StringName(str(potion_key))
		var existing := _potion_array(potion_id, target.get(potion_id, []))
		var incoming := _potion_array(potion_id, additions[potion_key])
		for instance: Dictionary in incoming:
			var uid := str(instance.get("instance_uid", ""))
			if uid.is_empty() or not existing.any(func(current: Dictionary) -> bool: return str(current.get("instance_uid", "")) == uid):
				existing.append(instance)
		target[potion_id] = existing
		_rebuild_default_throw_order(potion_id)


func _remove_potions(target: Dictionary, removals: Dictionary) -> void:
	for potion_key: Variant in removals:
		var potion_id := StringName(str(potion_key))
		var existing := _potion_array(potion_id, target.get(potion_id, []))
		var removal_value: Variant = removals[potion_key]
		if removal_value is Array:
			var requested_uids: Array = removal_value
			existing = existing.filter(func(item: Dictionary) -> bool: return not requested_uids.has(str(item.get("instance_uid", ""))))
		else:
			var remove_count := maxi(int(removal_value), 0)
			for _index in range(mini(remove_count, existing.size())):
				existing.pop_front()
		if existing.is_empty():
			target.erase(potion_id)
		else:
			target[potion_id] = existing


static func _normalize_potions(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is not Dictionary:
		return result
	for potion_key: Variant in value:
		var potion_id := StringName(str(potion_key))
		result[potion_id] = _potion_array(potion_id, value[potion_key])
	return result


static func _potion_array(potion_id: StringName, value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item_index in range(value.size()):
			var item: Variant = value[item_index]
			if item is Dictionary:
				var normalized := (item as Dictionary).duplicate(true)
				normalized["potion_id"] = str(normalized.get("potion_id", potion_id))
				normalized["instance_uid"] = str(normalized.get("instance_uid", ""))
				if normalized["instance_uid"].is_empty():
					normalized["instance_uid"] = _legacy_uid(potion_id, item_index, normalized)
				normalized["remaining_dose"] = clampf(float(normalized.get("remaining_dose", 1.0)), 0.0, 1.0)
				normalized["mixed_x"] = clampf(float(normalized.get("mixed_x", 0.0)), 0.0, 1.0)
				normalized["secondary_effect_id"] = str(normalized.get("secondary_effect_id", ""))
				normalized["quality"] = clampf(float(normalized.get("quality", 1.0)), 0.1, 1.5)
				normalized["secondary_effect_multiplier"] = clampf(float(normalized.get("secondary_effect_multiplier", 1.0)), 0.0, 1.0)
				normalized["potency"] = clampf(float(normalized.get("potency", 1.0)), 0.5, 1.25)
				normalized["duration"] = clampf(float(normalized.get("duration", 1.0)), 0.4, 1.3)
				normalized["price_multiplier"] = maxf(float(normalized.get("price_multiplier", 1.0)), 0.1)
				normalized["thermal_score"] = clampf(float(normalized.get("thermal_score", 1.0)), 0.0, 1.0)
				normalized["temperature_grade"] = str(normalized.get("temperature_grade", "stable_brew"))
				normalized["was_burned"] = bool(normalized.get("was_burned", false))
				normalized["created_day"] = maxi(int(normalized.get("created_day", 1)), 1)
				normalized["bottle_style_id"] = str(normalized.get("bottle_style_id", "health"))
				normalized["custom_name"] = str(normalized.get("custom_name", "")).left(12)
				normalized["actual_color"] = (normalized.get("actual_color", []) as Array).duplicate()
				normalized["traits"] = _string_array(normalized.get("traits", []))
				normalized["special_potion_id"] = str(normalized.get("special_potion_id", ""))
				result.append(normalized)
	elif value is int or value is float:
		for _index in range(maxi(int(value), 0)):
			result.append({
				"potion_id": str(potion_id),
				"instance_uid": _legacy_uid(potion_id, _index, {}),
				"remaining_dose": 1.0,
				"mixed_x": 0.0,
				"secondary_effect_id": "",
				"quality": 1.0,
				"secondary_effect_multiplier": 1.0,
				"potency": 1.0,
				"duration": 1.0,
				"price_multiplier": 1.0,
				"thermal_score": 1.0,
				"temperature_grade": "stable_brew",
				"was_burned": false,
				"created_day": 1,
				"bottle_style_id": "health",
				"custom_name": "",
				"actual_color": [],
				"traits": [],
				"special_potion_id": "",
			})
	return result


static func _count_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key: Variant in value:
			var count := maxi(int(value[key]), 0)
			if count > 0:
				result[StringName(str(key))] = count
	return result


static func _bool_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key: Variant in value:
			if bool(value[key]):
				result[str(key)] = true
	return result


static func _customer_state_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key: Variant in value:
			if value[key] is Dictionary:
				result[str(key)] = (value[key] as Dictionary).duplicate(true)
	return result


static func _daily_task_dictionary(value: Variant) -> Dictionary:
	if value is not Dictionary:
		return {}
	var source: Dictionary = value as Dictionary
	var task_id: String = str(source.get("id", ""))
	var task_day: int = int(source.get("day", -1))
	if task_id.is_empty() or task_day < 0:
		return {}
	return {
		"day": task_day,
		"id": task_id,
		"title": str(source.get("title", "")),
	}


static func _serialize_counts(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in value:
		result[str(key)] = maxi(int(value[key]), 0)
	return result


static func _serialize_potions(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in value:
		var potion_id := StringName(str(key))
		result[str(potion_id)] = _potion_array(potion_id, value[key])
	return result


static func _legacy_uid(potion_id: StringName, index: int, data: Dictionary) -> String:
	var signature := "%s|%d|%s|%s|%s|%s" % [potion_id, index, data.get("created_day", 1), data.get("quality", 1.0), data.get("mixed_x", 0.0), data.get("thermal_score", 1.0)]
	return "legacy-%s-%08x" % [potion_id, signature.hash() & 0xffffffff]


static func _normalize_throw_orders(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for key: Variant in value:
			var order: Array[String] = []
			if value[key] is Array:
				for uid: Variant in value[key]:
					order.append(str(uid))
			result[StringName(str(key))] = order
	return result


static func _serialize_throw_orders(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in value:
		result[str(key)] = Array(value[key]).duplicate()
	return result


func _cleanup_potion_configuration() -> void:
	potion_slot_count = clampi(potion_slot_count, DEFAULT_POTION_SLOT_COUNT, MAX_POTION_SLOT_COUNT)
	while equipped_potion_ids.size() < potion_slot_count:
		equipped_potion_ids.append(&"")
	if equipped_potion_ids.size() > potion_slot_count:
		equipped_potion_ids.resize(potion_slot_count)
	var equipped_once: Dictionary = {}
	for index in range(equipped_potion_ids.size()):
		if equipped_potion_ids[index] == &"black_potion":
			equipped_potion_ids[index] = &""
		elif equipped_potion_ids[index] != &"" and not is_potion_throwable_unlocked(equipped_potion_ids[index]):
			equipped_potion_ids[index] = &""
		elif equipped_potion_ids[index] != &"":
			if equipped_once.has(equipped_potion_ids[index]):
				equipped_potion_ids[index] = &""
			else:
				equipped_once[equipped_potion_ids[index]] = true
	selected_potion_slot = clampi(selected_potion_slot, 0, potion_slot_count - 1)
	for ordered_potion_key: Variant in potion_throw_orders.keys():
		if not potions.has(StringName(str(ordered_potion_key))):
			potion_throw_orders.erase(ordered_potion_key)
	for potion_key: Variant in potions:
		_rebuild_default_throw_order(StringName(str(potion_key)))


func _migrate_legacy_potion_unlocks() -> void:
	var legacy_ids: Array[StringName] = []
	for potion_key: Variant in potions:
		legacy_ids.append(StringName(str(potion_key)))
	for potion_id: StringName in equipped_potion_ids:
		if potion_id != &"" and not legacy_ids.has(potion_id):
			legacy_ids.append(potion_id)
	for potion_id: StringName in legacy_ids:
		var recipe_id: StringName = BASE_RECIPE_BY_POTION.get(potion_id, &"")
		if recipe_id != &"":
			unlock_potion_recipe(recipe_id)
		if potion_id != &"cyan_potion" or has_event_flag(&"springburst_throwable_unlocked"):
			unlock_throwable_potion(potion_id)


func _rebuild_default_throw_order(potion_id: StringName) -> void:
	var instances: Array[Dictionary] = _potion_array(potion_id, potions.get(potion_id, []))
	potions[potion_id] = instances
	var existing_order: Array = potion_throw_orders.get(potion_id, [])
	var valid_uids: Array[String] = []
	for instance in instances:
		valid_uids.append(str(instance.get("instance_uid", "")))
	var rebuilt: Array[String] = []
	for uid: Variant in existing_order:
		if valid_uids.has(str(uid)) and not rebuilt.has(str(uid)):
			rebuilt.append(str(uid))
	var missing := instances.filter(func(item: Dictionary) -> bool: return not rebuilt.has(str(item.get("instance_uid", ""))))
	missing.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("quality", 1.0)) < float(b.get("quality", 1.0)))
	for item: Dictionary in missing:
		var item_uid := str(item.get("instance_uid", ""))
		var item_quality := float(item.get("quality", 1.0))
		var insert_at := rebuilt.size()
		for index in range(rebuilt.size()):
			var existing := instances.filter(func(candidate: Dictionary) -> bool: return str(candidate.get("instance_uid", "")) == rebuilt[index])
			if not existing.is_empty() and float(existing[0].get("quality", 1.0)) > item_quality:
				insert_at = index
				break
		rebuilt.insert(insert_at, item_uid)
	potion_throw_orders[potion_id] = rebuilt


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item: Variant in value:
			result.append(StringName(str(item)))
	return result


static func _vector2i_array(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if value is Array:
		for entry: Variant in value:
			var cell := Vector2i.ZERO
			if entry is Vector2i:
				cell = entry
			elif entry is Array and (entry as Array).size() >= 2:
				cell = Vector2i(int((entry as Array)[0]), int((entry as Array)[1]))
			else:
				continue
			if not result.has(cell):
				result.append(cell)
	return result


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result

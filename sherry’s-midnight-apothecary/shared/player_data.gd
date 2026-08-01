class_name PlayerData
extends Resource

const SAVE_VERSION := 2

var max_health := 100
var health := 100
var money := 0
var debt := 0
var inventory: Dictionary = {}
var potions: Dictionary = {}
var upgrades: Array[StringName] = []
var unlocked_levels: Array[StringName] = [&"market"]


func reset() -> void:
	max_health = 100
	health = max_health
	money = 0
	debt = 0
	inventory = {}
	potions = {}
	upgrades = []
	unlocked_levels = [&"market"]


func apply_day_result(result: DayResult) -> void:
	health = clampi(result.remaining_health, 0, max_health)
	_add_counts(inventory, result.collected_items)
	potions = _normalize_potions(result.remaining_potions)
	if result.unlocked_level_id != &"" and not unlocked_levels.has(result.unlocked_level_id):
		unlocked_levels.append(result.unlocked_level_id)


func apply_night_result(result: NightResult) -> void:
	money += result.earned_money
	_subtract_counts(inventory, result.spent_ingredients)
	_append_potions(potions, result.produced_potions)
	_remove_potions(potions, result.sold_potions)


func to_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"max_health": max_health,
		"health": health,
		"money": money,
		"debt": debt,
		"inventory": _serialize_counts(inventory),
		"potions": _serialize_potions(potions),
		"upgrades": upgrades.map(func(value: StringName) -> String: return str(value)),
		"unlocked_levels": unlocked_levels.map(func(value: StringName) -> String: return str(value)),
	}


static func from_save_data(data: Dictionary) -> PlayerData:
	var result := PlayerData.new()
	result.max_health = maxi(int(data.get("max_health", 100)), 1)
	result.health = clampi(int(data.get("health", result.max_health)), 0, result.max_health)
	result.money = int(data.get("money", 0))
	result.debt = int(data.get("debt", 0))
	result.inventory = _count_dictionary(data.get("inventory", {}))
	result.potions = _normalize_potions(data.get("potions", {}))
	result.upgrades = _string_name_array(data.get("upgrades", []))
	result.unlocked_levels = _string_name_array(data.get("unlocked_levels", [&"market"]))
	return result


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
		existing.append_array(incoming)
		target[potion_id] = existing


func _remove_potions(target: Dictionary, removals: Dictionary) -> void:
	for potion_key: Variant in removals:
		var potion_id := StringName(str(potion_key))
		var existing := _potion_array(potion_id, target.get(potion_id, []))
		var remove_count := maxi(int(removals[potion_key]), 0)
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
		for item: Variant in value:
			if item is Dictionary:
				var normalized := (item as Dictionary).duplicate(true)
				normalized["potion_id"] = str(normalized.get("potion_id", potion_id))
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
				result.append(normalized)
	elif value is int or value is float:
		for _index in range(maxi(int(value), 0)):
			result.append({
				"potion_id": str(potion_id),
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


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item: Variant in value:
			result.append(StringName(str(item)))
	return result

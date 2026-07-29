class_name PlayerData
extends Resource

const SAVE_VERSION := 1

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
	potions = result.remaining_potions.duplicate(true)
	if result.unlocked_level_id != &"" and not unlocked_levels.has(result.unlocked_level_id):
		unlocked_levels.append(result.unlocked_level_id)


func apply_night_result(result: NightResult) -> void:
	money += result.earned_money
	_subtract_counts(inventory, result.spent_ingredients)
	_add_counts(potions, result.produced_potions)
	_subtract_counts(potions, result.sold_potions)


func to_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"max_health": max_health,
		"health": health,
		"money": money,
		"debt": debt,
		"inventory": inventory.duplicate(true),
		"potions": potions.duplicate(true),
		"upgrades": upgrades.duplicate(),
		"unlocked_levels": unlocked_levels.duplicate(),
	}


static func from_save_data(data: Dictionary) -> PlayerData:
	var result := PlayerData.new()
	result.max_health = maxi(int(data.get("max_health", 100)), 1)
	result.health = clampi(int(data.get("health", result.max_health)), 0, result.max_health)
	result.money = int(data.get("money", 0))
	result.debt = int(data.get("debt", 0))
	result.inventory = _dictionary_copy(data.get("inventory", {}))
	result.potions = _dictionary_copy(data.get("potions", {}))
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


static func _dictionary_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item: Variant in value:
			result.append(StringName(str(item)))
	return result

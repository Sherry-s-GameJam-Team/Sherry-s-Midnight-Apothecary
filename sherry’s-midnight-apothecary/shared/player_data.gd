class_name PlayerData
extends Resource

const SAVE_VERSION := 4
const DEFAULT_POTION_SLOT_COUNT := 3
const MAX_POTION_SLOT_COUNT := 8
const DEFAULT_EQUIPPED_POTIONS: Array[StringName] = [&"red_potion", &"green_potion", &"orange_potion"]

var max_health := 100
var health := 100
var money := 0
var debt := 0
var inventory: Dictionary = {}
var potions: Dictionary = {}
var potion_slot_count := DEFAULT_POTION_SLOT_COUNT
var equipped_potion_ids: Array[StringName] = DEFAULT_EQUIPPED_POTIONS.duplicate()
var selected_potion_slot := 0
var potion_throw_orders: Dictionary = {}
var upgrades: Array[StringName] = []
var unlocked_levels: Array[StringName] = [&"market"]
var tutorial_flags: Dictionary = {}


func reset() -> void:
	max_health = 100
	health = max_health
	money = 0
	debt = 0
	inventory = {}
	potions = {}
	potion_slot_count = DEFAULT_POTION_SLOT_COUNT
	equipped_potion_ids = DEFAULT_EQUIPPED_POTIONS.duplicate()
	selected_potion_slot = 0
	potion_throw_orders = {}
	upgrades = []
	unlocked_levels = [&"market"]
	tutorial_flags = {}


func apply_day_result(result: DayResult) -> void:
	health = clampi(result.remaining_health, 0, max_health)
	_add_counts(inventory, result.collected_items)
	potions = _normalize_potions(result.remaining_potions)
	_cleanup_potion_configuration()
	if result.unlocked_level_id != &"" and not unlocked_levels.has(result.unlocked_level_id):
		unlocked_levels.append(result.unlocked_level_id)


func apply_night_result(result: NightResult) -> void:
	money += result.earned_money
	_subtract_counts(inventory, result.spent_ingredients)
	_append_potions(potions, result.produced_potions)
	_remove_potions(potions, result.sold_potions)
	_cleanup_potion_configuration()


func to_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"max_health": max_health,
		"health": health,
		"money": money,
		"debt": debt,
		"inventory": _serialize_counts(inventory),
		"potions": _serialize_potions(potions),
		"potion_slot_count": potion_slot_count,
		"equipped_potion_ids": equipped_potion_ids.map(func(value: StringName) -> String: return str(value)),
		"selected_potion_slot": selected_potion_slot,
		"potion_throw_orders": _serialize_throw_orders(potion_throw_orders),
		"upgrades": upgrades.map(func(value: StringName) -> String: return str(value)),
		"unlocked_levels": unlocked_levels.map(func(value: StringName) -> String: return str(value)),
		"tutorial_flags": tutorial_flags.duplicate(),
	}


static func from_save_data(data: Dictionary) -> PlayerData:
	var result := PlayerData.new()
	result.max_health = maxi(int(data.get("max_health", 100)), 1)
	result.health = clampi(int(data.get("health", result.max_health)), 0, result.max_health)
	result.money = int(data.get("money", 0))
	result.debt = int(data.get("debt", 0))
	result.inventory = _count_dictionary(data.get("inventory", {}))
	result.potions = _normalize_potions(data.get("potions", {}))
	result.potion_slot_count = clampi(int(data.get("potion_slot_count", DEFAULT_POTION_SLOT_COUNT)), DEFAULT_POTION_SLOT_COUNT, MAX_POTION_SLOT_COUNT)
	result.equipped_potion_ids = _string_name_array(data.get("equipped_potion_ids", DEFAULT_EQUIPPED_POTIONS))
	result.selected_potion_slot = clampi(int(data.get("selected_potion_slot", 0)), 0, result.potion_slot_count - 1)
	result.potion_throw_orders = _normalize_throw_orders(data.get("potion_throw_orders", {}))
	result.upgrades = _string_name_array(data.get("upgrades", []))
	result.unlocked_levels = _string_name_array(data.get("unlocked_levels", [&"market"]))
	result.tutorial_flags = _bool_dictionary(data.get("tutorial_flags", {}))
	result._cleanup_potion_configuration()
	return result


func unlock_potion_slot(amount: int = 1) -> void:
	potion_slot_count = clampi(potion_slot_count + maxi(amount, 0), DEFAULT_POTION_SLOT_COUNT, MAX_POTION_SLOT_COUNT)
	while equipped_potion_ids.size() < potion_slot_count:
		equipped_potion_ids.append(&"")


func equip_potion(slot_index: int, potion_id: StringName) -> bool:
	if slot_index < 0 or slot_index >= potion_slot_count or potion_id == &"" or potion_id == &"black_potion":
		return false
	for index in range(equipped_potion_ids.size()):
		if index != slot_index and equipped_potion_ids[index] == potion_id:
			return false
	while equipped_potion_ids.size() < potion_slot_count:
		equipped_potion_ids.append(&"")
	equipped_potion_ids[slot_index] = potion_id
	return true


func unequip_potion(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < equipped_potion_ids.size():
		equipped_potion_ids[slot_index] = &""


func select_potion_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < potion_slot_count:
		selected_potion_slot = slot_index


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

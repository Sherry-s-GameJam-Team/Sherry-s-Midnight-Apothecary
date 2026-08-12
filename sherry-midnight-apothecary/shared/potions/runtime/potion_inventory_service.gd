class_name PotionInventoryService
extends RefCounted

const DOSE_EPSILON := 0.0001

var player_data: PlayerData
var _next_reservation_id := 1
var _reserved_by_uid: Dictionary = {}
var _reservations: Dictionary = {}


func _init(shared_player_data: PlayerData = null) -> void:
	player_data = shared_player_data


func setup(shared_player_data: PlayerData) -> void:
	player_data = shared_player_data
	_reserved_by_uid.clear()
	_reservations.clear()
	_normalize_all()


func reserve_dose(potion_id: StringName, dose: float) -> PotionDoseReservation:
	if player_data == null or potion_id == &"" or potion_id == &"black_potion" or dose <= DOSE_EPSILON:
		return null
	_normalize_type(potion_id)
	var reservation := PotionDoseReservation.new()
	reservation.reservation_id = _next_reservation_id
	reservation.potion_id = potion_id
	reservation.requested_dose = dose
	_next_reservation_id += 1
	var needed := dose
	for uid: String in _ordered_uids(potion_id):
		var instance := _find_instance(potion_id, uid)
		if instance.is_empty():
			continue
		var available := maxf(float(instance.get("remaining_dose", 1.0)) - float(_reserved_by_uid.get(uid, 0.0)), 0.0)
		if available <= DOSE_EPSILON:
			continue
		var taken := minf(available, needed)
		reservation.allocations.append({"instance_uid": uid, "dose": taken})
		_reserved_by_uid[uid] = float(_reserved_by_uid.get(uid, 0.0)) + taken
		needed -= taken
		if needed <= DOSE_EPSILON:
			break
	if needed > DOSE_EPSILON:
		_release_allocations(reservation)
		reservation.active = false
		return null
	_reservations[reservation.reservation_id] = reservation
	return reservation


func commit_reservation(reservation: PotionDoseReservation) -> Dictionary:
	if not _is_active_reservation(reservation):
		return {}
	var instances: Array[Dictionary] = player_data.potions.get(reservation.potion_id, [])
	var consumed_parts: Array[Dictionary] = []
	for allocation: Dictionary in reservation.allocations:
		var uid := str(allocation.get("instance_uid", ""))
		var dose := float(allocation.get("dose", 0.0))
		var found := false
		for instance: Dictionary in instances:
			if str(instance.get("instance_uid", "")) != uid:
				continue
			if float(instance.get("remaining_dose", 0.0)) + DOSE_EPSILON < dose:
				cancel_reservation(reservation)
				return {}
			var part := instance.duplicate(true)
			part["consumed_dose"] = dose
			consumed_parts.append(part)
			instance["remaining_dose"] = maxf(float(instance.get("remaining_dose", 0.0)) - dose, 0.0)
			found = true
			break
		if not found:
			cancel_reservation(reservation)
			return {}
	instances = instances.filter(func(item: Dictionary) -> bool: return float(item.get("remaining_dose", 0.0)) > DOSE_EPSILON)
	if instances.is_empty():
		player_data.potions.erase(reservation.potion_id)
	else:
		player_data.potions[reservation.potion_id] = instances
	_release_allocations(reservation)
	_reservations.erase(reservation.reservation_id)
	reservation.active = false
	_cleanup_order(reservation.potion_id)
	return _mix_consumed_parts(reservation.potion_id, consumed_parts, reservation.requested_dose)


func cancel_reservation(reservation: PotionDoseReservation) -> void:
	if not _is_active_reservation(reservation):
		return
	_release_allocations(reservation)
	_reservations.erase(reservation.reservation_id)
	reservation.active = false


func get_total_dose(potion_id: StringName) -> float:
	if player_data == null:
		return 0.0
	_normalize_type(potion_id)
	var total := 0.0
	for instance: Dictionary in player_data.potions.get(potion_id, []):
		total += float(instance.get("remaining_dose", 1.0))
	return total


func get_available_dose(potion_id: StringName) -> float:
	if player_data == null:
		return 0.0
	_normalize_type(potion_id)
	var total := 0.0
	for instance: Dictionary in player_data.potions.get(potion_id, []):
		var uid := str(instance.get("instance_uid", ""))
		total += maxf(float(instance.get("remaining_dose", 1.0)) - float(_reserved_by_uid.get(uid, 0.0)), 0.0)
	return total


func get_instances(potion_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if player_data == null:
		return result
	_normalize_type(potion_id)
	var stored_instances: Variant = player_data.potions.get(potion_id, [])
	if stored_instances is Array:
		for stored_instance: Variant in stored_instances:
			if stored_instance is Dictionary:
				result.append((stored_instance as Dictionary).duplicate(true))
	return result


func get_next_instance(potion_id: StringName) -> Dictionary:
	_normalize_type(potion_id)
	var order := _ordered_uids(potion_id)
	return _find_instance(potion_id, order[0]).duplicate(true) if not order.is_empty() else {}


func set_throw_order(potion_id: StringName, ordered_uids: Array[String]) -> void:
	if player_data == null:
		return
	_normalize_type(potion_id)
	var valid: Array[String] = []
	for instance: Dictionary in player_data.potions.get(potion_id, []):
		valid.append(str(instance.get("instance_uid", "")))
	var cleaned: Array[String] = []
	for uid: String in ordered_uids:
		if valid.has(uid) and not cleaned.has(uid):
			cleaned.append(uid)
	for uid: String in _default_quality_order(potion_id):
		if not cleaned.has(uid):
			var incoming := _find_instance(potion_id, uid)
			var insert_at := cleaned.size()
			for index in range(cleaned.size()):
				var existing := _find_instance(potion_id, cleaned[index])
				if not existing.is_empty() and float(existing.get("quality", 1.0)) > float(incoming.get("quality", 1.0)):
					insert_at = index
					break
			cleaned.insert(insert_at, uid)
	player_data.potion_throw_orders[potion_id] = cleaned


func get_partial_sale_ratio(instance: Dictionary) -> float:
	return clampf(float(instance.get("remaining_dose", 1.0)), 0.0, 1.0)


func calculate_instance_sale_value(potion: PotionData, instance: Dictionary) -> int:
	if potion == null:
		return 0
	var full_value := float(potion.base_price) * maxf(float(instance.get("price_multiplier", 1.0)), 0.1)
	return maxi(roundi(full_value * get_partial_sale_ratio(instance)), 0)


func _normalize_all() -> void:
	if player_data == null:
		return
	player_data.potions = PlayerData._normalize_potions(player_data.potions)
	for potion_key: Variant in player_data.potions:
		_normalize_type(StringName(str(potion_key)))


func _normalize_type(potion_id: StringName) -> void:
	if player_data == null:
		return
	var normalized := PlayerData._potion_array(potion_id, player_data.potions.get(potion_id, []))
	if normalized.is_empty():
		player_data.potions.erase(potion_id)
	else:
		player_data.potions[potion_id] = normalized
	_cleanup_order(potion_id)


func _cleanup_order(potion_id: StringName) -> void:
	if player_data == null:
		return
	var valid: Array[String] = []
	for instance: Dictionary in player_data.potions.get(potion_id, []):
		valid.append(str(instance.get("instance_uid", "")))
	var cleaned: Array[String] = []
	for uid: Variant in player_data.potion_throw_orders.get(potion_id, []):
		if valid.has(str(uid)) and not cleaned.has(str(uid)):
			cleaned.append(str(uid))
	for uid: String in _default_quality_order(potion_id):
		if not cleaned.has(uid):
			cleaned.append(uid)
	player_data.potion_throw_orders[potion_id] = cleaned


func _ordered_uids(potion_id: StringName) -> Array[String]:
	_cleanup_order(potion_id)
	var result: Array[String] = []
	for uid: Variant in player_data.potion_throw_orders.get(potion_id, []):
		result.append(str(uid))
	return result


func _default_quality_order(potion_id: StringName) -> Array[String]:
	var instances: Array = player_data.potions.get(potion_id, []).duplicate()
	instances.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var quality_a := float(a.get("quality", 1.0))
		var quality_b := float(b.get("quality", 1.0))
		return quality_a < quality_b if not is_equal_approx(quality_a, quality_b) else str(a.get("instance_uid", "")) < str(b.get("instance_uid", ""))
	)
	var result: Array[String] = []
	for instance: Dictionary in instances:
		result.append(str(instance.get("instance_uid", "")))
	return result


func _find_instance(potion_id: StringName, uid: String) -> Dictionary:
	if player_data == null:
		return {}
	for instance: Dictionary in player_data.potions.get(potion_id, []):
		if str(instance.get("instance_uid", "")) == uid:
			return instance
	return {}


func _is_active_reservation(reservation: PotionDoseReservation) -> bool:
	return reservation != null and reservation.active and _reservations.get(reservation.reservation_id) == reservation


func _release_allocations(reservation: PotionDoseReservation) -> void:
	for allocation: Dictionary in reservation.allocations:
		var uid := str(allocation.get("instance_uid", ""))
		var remaining := maxf(float(_reserved_by_uid.get(uid, 0.0)) - float(allocation.get("dose", 0.0)), 0.0)
		if remaining <= DOSE_EPSILON:
			_reserved_by_uid.erase(uid)
		else:
			_reserved_by_uid[uid] = remaining


func _mix_consumed_parts(potion_id: StringName, parts: Array[Dictionary], total_dose: float) -> Dictionary:
	var result := {
		"potion_id": str(potion_id),
		"consumed_dose": total_dose,
		"quality": 0.0,
		"potency": 0.0,
		"duration": 0.0,
		"price_multiplier": 0.0,
		"thermal_score": 0.0,
		"mixed_x": 0.0,
		"secondary_effect_id": "",
		"secondary_effect_multiplier": 0.0,
		"was_burned": false,
		"source_instance_uids": [],
	}
	var secondary_weights: Dictionary = {}
	var secondary_multipliers: Dictionary = {}
	for part: Dictionary in parts:
		var weight := float(part.get("consumed_dose", 0.0)) / maxf(total_dose, DOSE_EPSILON)
		for field in ["quality", "potency", "duration", "price_multiplier", "thermal_score", "mixed_x"]:
			result[field] = float(result[field]) + float(part.get(field, 1.0 if field != "mixed_x" else 0.0)) * weight
		result["was_burned"] = bool(result["was_burned"]) or bool(part.get("was_burned", false))
		result["source_instance_uids"].append(str(part.get("instance_uid", "")))
		var secondary_id := str(part.get("secondary_effect_id", ""))
		if not secondary_id.is_empty():
			secondary_weights[secondary_id] = float(secondary_weights.get(secondary_id, 0.0)) + weight
			secondary_multipliers[secondary_id] = float(secondary_multipliers.get(secondary_id, 0.0)) + float(part.get("secondary_effect_multiplier", 0.0)) * weight
	var chosen_secondary := ""
	var chosen_weight := 0.0
	for effect_id: Variant in secondary_weights:
		if float(secondary_weights[effect_id]) > chosen_weight:
			chosen_secondary = str(effect_id)
			chosen_weight = float(secondary_weights[effect_id])
	result["secondary_effect_id"] = chosen_secondary
	result["secondary_effect_multiplier"] = float(secondary_multipliers.get(chosen_secondary, 0.0))
	return result

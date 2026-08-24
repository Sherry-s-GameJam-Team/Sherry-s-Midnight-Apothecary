class_name RemotePotionSupply
extends Node

const UNLOCK_FLAG: StringName = &"enzo_remote_supply_unlocked"
const MAX_BOTTLES_PER_TYPE := 4
const ELIGIBLE_POTION_IDS: Array[StringName] = [
	&"red_potion",
	&"orange_potion",
	&"yellow_potion",
	&"green_potion",
	&"cyan_potion",
	&"blue_potion",
	&"purple_potion",
]

@export_range(5.0, 300.0, 1.0) var supply_interval_seconds := 45.0
@export_range(0.001, 0.1, 0.001) var dose_restore_per_second := 0.01

var player_data: PlayerData
var level_scope_active := false
var _elapsed_supply_time := 0.0
var _round_robin_cursor := 0
var _instance_serial := 0


func _ready() -> void:
	set_process(player_data != null)


func setup(shared_player_data: PlayerData) -> void:
	player_data = shared_player_data
	_elapsed_supply_time = 0.0
	if is_node_ready():
		set_process(player_data != null)


func set_level_scope_active(active: bool) -> void:
	if level_scope_active == active:
		return
	level_scope_active = active
	if not active:
		_elapsed_supply_time = 0.0


func _process(delta: float) -> void:
	advance_supply_time(delta)


## Gradually restores the current bottle shown in every equipped throw slot.
## The new-bottle clock starts only after those displayed bottles are full.
func advance_supply_time(delta: float) -> StringName:
	if player_data == null:
		return &""
	if not player_data.has_event_flag(UNLOCK_FLAG) or not level_scope_active:
		_elapsed_supply_time = 0.0
		return &""
	var restored_id := _restore_equipped_current_bottles(maxf(delta, 0.0))
	if restored_id != &"":
		_elapsed_supply_time = 0.0
		return restored_id
	var shortages := _shortage_ids()
	if shortages.is_empty():
		_elapsed_supply_time = 0.0
		return &""
	_elapsed_supply_time += maxf(delta, 0.0)
	if _elapsed_supply_time < supply_interval_seconds:
		return &""
	_elapsed_supply_time = maxf(_elapsed_supply_time - supply_interval_seconds, 0.0)
	var potion_id: StringName = shortages[_round_robin_cursor % shortages.size()]
	_round_robin_cursor += 1
	_add_supply_bottle(potion_id)
	return potion_id


func _restore_equipped_current_bottles(delta: float) -> StringName:
	if delta <= 0.0:
		return &""
	var first_restored_id: StringName = &""
	for potion_id: StringName in _unique_equipped_ids():
		var instances: Array = player_data.potions.get(potion_id, [])
		var current_index := _current_throw_instance_index(potion_id, instances)
		if current_index < 0:
			continue
		var instance: Dictionary = instances[current_index]
		var remaining := float(instance.get("remaining_dose", 1.0))
		if remaining <= PotionInventoryService.DOSE_EPSILON or remaining >= 1.0 - PotionInventoryService.DOSE_EPSILON:
			continue
		instance["remaining_dose"] = minf(remaining + dose_restore_per_second * delta, 1.0)
		instances[current_index] = instance
		player_data.potions[potion_id] = instances
		if first_restored_id == &"":
			first_restored_id = potion_id
	return first_restored_id


func _current_throw_instance_index(potion_id: StringName, instances: Array) -> int:
	if instances.is_empty():
		return -1
	var ordered_uids: Array = player_data.potion_throw_orders.get(potion_id, [])
	for ordered_uid: Variant in ordered_uids:
		for index in range(instances.size()):
			var instance: Dictionary = instances[index]
			if str(instance.get("instance_uid", "")) == str(ordered_uid):
				return index
	return 0


func _unique_equipped_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for potion_id: StringName in player_data.equipped_potion_ids:
		if ELIGIBLE_POTION_IDS.has(potion_id) and player_data.is_potion_throwable_unlocked(potion_id) and not result.has(potion_id):
			result.append(potion_id)
	return result


func _tracked_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if player_data == null:
		return result
	for potion_id: StringName in player_data.throwable_potion_ids:
		if ELIGIBLE_POTION_IDS.has(potion_id) and not result.has(potion_id):
			result.append(potion_id)
	result.sort()
	return result


func _shortage_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for potion_id: StringName in _tracked_ids():
		if player_data.potion_count(potion_id) < MAX_BOTTLES_PER_TYPE:
			result.append(potion_id)
	return result


func _add_supply_bottle(potion_id: StringName) -> void:
	_instance_serial += 1
	player_data.add_brewed_potion({
		"potion_id": str(potion_id),
		"instance_uid": "enzo_remote_supply_%d_%d" % [Time.get_ticks_msec(), _instance_serial],
		"remaining_dose": 1.0,
		"quality": 1.0,
		"potency": 1.0,
		"custom_name": "",
		"traits": [&"remote_supply"],
	})

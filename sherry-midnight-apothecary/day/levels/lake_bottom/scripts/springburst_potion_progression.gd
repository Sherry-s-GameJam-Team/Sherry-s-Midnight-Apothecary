class_name SpringburstPotionProgression
extends RefCounted

## Keeps the commissioned Springburst bottles out of the combat loadout until
## the Tide Eye has been defeated, while preserving old saves that already
## received cyan_potion instances from the previous flow.

const STORY_ITEM_ID: StringName = &"springburst_potion_commission"
const POTION_ID: StringName = &"cyan_potion"
const THROWABLE_UNLOCKED_FLAG: StringName = &"springburst_throwable_unlocked"
const REMOTE_SUPPLY_UNLOCKED_FLAG: StringName = &"enzo_remote_supply_unlocked"


static func grant_story_bottles(player_data: PlayerData, amount: int = 4) -> void:
	if player_data == null or amount <= 0:
		return
	player_data.add_story_item(STORY_ITEM_ID, amount)


static func enforce_story_item_phase(player_data: PlayerData) -> int:
	if player_data == null or player_data.has_event_flag(THROWABLE_UNLOCKED_FLAG):
		return 0
	var stored_value: Variant = player_data.potions.get(POTION_ID, [])
	var stored_instances: Array = stored_value if stored_value is Array else []
	var moved_count := stored_instances.size()
	if moved_count > 0:
		player_data.potions.erase(POTION_ID)
		player_data.potion_throw_orders.erase(POTION_ID)
		player_data.add_story_item(STORY_ITEM_ID, moved_count)
	for slot in range(player_data.equipped_potion_ids.size()):
		if player_data.equipped_potion_ids[slot] == POTION_ID:
			player_data.unequip_potion(slot)
	return moved_count


static func unlock_throwable_after_boss(player_data: PlayerData) -> int:
	if player_data == null:
		return 0
	if player_data.has_event_flag(THROWABLE_UNLOCKED_FLAG):
		# Backfill remote supply for saves that received the throwable reward
		# before the replenishment system was introduced.
		player_data.set_event_flag(REMOTE_SUPPLY_UNLOCKED_FLAG)
		return 0
	var bottle_count := int(player_data.story_items.get(STORY_ITEM_ID, 0))
	if bottle_count <= 0:
		bottle_count = 4
	player_data.remove_story_item(STORY_ITEM_ID, bottle_count)
	for index in range(bottle_count):
		player_data.add_brewed_potion({
			"potion_id": str(POTION_ID),
			"instance_uid": "tide_eye_reward_%d_%d" % [Time.get_ticks_msec(), index],
			"remaining_dose": 1.0,
			"quality": 1.0,
			"potency": 1.0,
			"created_day": 2,
			"custom_name": "涌水药水",
			"traits": [&"flow_control", &"water_generation"],
		})
	player_data.set_event_flag(THROWABLE_UNLOCKED_FLAG)
	player_data.set_event_flag(REMOTE_SUPPLY_UNLOCKED_FLAG)
	_equip_if_possible(player_data)
	return bottle_count


static func _equip_if_possible(player_data: PlayerData) -> void:
	if player_data.equipped_potion_ids.has(POTION_ID):
		return
	for slot in range(player_data.potion_slot_count):
		if player_data.equipped_potion_ids[slot] == &"":
			player_data.equip_potion(slot, POTION_ID)
			player_data.select_potion_slot(slot)
			return
	player_data.equip_potion(0, POTION_ID)
	player_data.select_potion_slot(0)

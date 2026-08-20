class_name StoryEventCondition
extends Resource

enum Type {
	DAY_RANGE,
	EVENT_FLAG_SET,
	EVENT_FLAG_CLEAR,
	STORY_ITEM_AT_LEAST,
	INVENTORY_AT_LEAST,
	LEVEL_UNLOCKED,
	MONEY_AT_LEAST,
	REPUTATION_AT_LEAST,
}

@export var type: Type = Type.DAY_RANGE
@export var key: StringName = &""
@export var minimum_day := 0
@export var maximum_day := 30
@export var amount := 1


func is_met(player_data: PlayerData, current_day: int) -> bool:
	if player_data == null:
		return false
	match type:
		Type.DAY_RANGE:
			return current_day >= minimum_day and current_day <= maximum_day
		Type.EVENT_FLAG_SET:
			return player_data.has_event_flag(key)
		Type.EVENT_FLAG_CLEAR:
			return not player_data.has_event_flag(key)
		Type.STORY_ITEM_AT_LEAST:
			return int(player_data.story_items.get(key, 0)) >= amount
		Type.INVENTORY_AT_LEAST:
			return int(player_data.inventory.get(key, 0)) >= amount
		Type.LEVEL_UNLOCKED:
			return player_data.has_unlocked_level(key)
		Type.MONEY_AT_LEAST:
			return player_data.money >= amount
		Type.REPUTATION_AT_LEAST:
			return player_data.store_reputation >= amount
	return false

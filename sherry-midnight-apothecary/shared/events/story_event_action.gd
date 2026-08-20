class_name StoryEventAction
extends Resource

enum Type {
	SET_EVENT_FLAG,
	CLEAR_EVENT_FLAG,
	GRANT_STORY_ITEM,
	GRANT_INVENTORY_ITEM,
	UNLOCK_LEVEL,
	SET_DAILY_TASK,
}

@export var type: Type = Type.SET_EVENT_FLAG
@export var key: StringName = &""
@export_range(1, 999, 1) var amount := 1
@export_multiline var task_title := ""


func apply_to(player_data: PlayerData, current_day: int = -1) -> bool:
	if player_data == null or key == &"":
		return false
	match type:
		Type.SET_EVENT_FLAG:
			return player_data.set_event_flag(key)
		Type.CLEAR_EVENT_FLAG:
			return player_data.clear_event_flag(key)
		Type.GRANT_STORY_ITEM:
			player_data.add_story_item(key, amount)
			return true
		Type.GRANT_INVENTORY_ITEM:
			player_data.add_inventory_item(key, amount)
			return true
		Type.UNLOCK_LEVEL:
			return player_data.unlock_level(key) or player_data.has_unlocked_level(key)
		Type.SET_DAILY_TASK:
			return player_data.set_active_daily_task(key, task_title, current_day)
	return false

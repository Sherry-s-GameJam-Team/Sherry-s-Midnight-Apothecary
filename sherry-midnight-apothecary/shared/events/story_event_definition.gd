class_name StoryEventDefinition
extends Resource

@export var id: StringName = &""
@export var priority := 0
@export var trigger: StoryEventTriggerSpec
@export var conditions: Array[StoryEventCondition] = []
@export var dialogue_resource: DialogueResource
@export var dialogue_title: StringName = &"start"
@export var actions: Array[StoryEventAction] = []


func completion_flag() -> StringName:
	return StringName("story_event_completed:%s" % id)


func conditions_are_met(player_data: PlayerData, current_day: int) -> bool:
	if id == &"" or trigger == null or player_data == null:
		return false
	if player_data.has_event_flag(completion_flag()):
		return false
	for condition: StoryEventCondition in conditions:
		if condition == null or not condition.is_met(player_data, current_day):
			return false
	return true

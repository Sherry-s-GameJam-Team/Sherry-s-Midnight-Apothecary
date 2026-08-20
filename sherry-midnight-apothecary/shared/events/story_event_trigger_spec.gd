class_name StoryEventTriggerSpec
extends Resource

enum Type {
	RUNTIME_ENTERED,
	LEVEL_ENTERED,
	INTERACTION,
}

enum RuntimeMode {
	ANY,
	DAY,
	NIGHT,
}

@export var type: Type = Type.RUNTIME_ENTERED
@export var runtime_mode: RuntimeMode = RuntimeMode.ANY
@export var level_id: StringName = &""
@export var interaction_key: StringName = &""


func matches(request_type: Type, is_night: bool, requested_level_id: StringName, requested_interaction_key: StringName) -> bool:
	if type != request_type:
		return false
	if runtime_mode == RuntimeMode.DAY and is_night:
		return false
	if runtime_mode == RuntimeMode.NIGHT and not is_night:
		return false
	if type == Type.LEVEL_ENTERED and level_id != requested_level_id:
		return false
	if type == Type.INTERACTION and interaction_key != requested_interaction_key:
		return false
	return true

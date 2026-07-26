class_name LevelEntryState
extends RefCounted

var source_level_id: StringName = &""
var target_level_id: StringName = &""
var entry_id: StringName = &"default"
var player_facing: int = 1
var player_velocity: Vector2 = Vector2.ZERO
var camera_state: Dictionary = {}
var custom_data: Dictionary = {}

func to_dictionary() -> Dictionary:
	return {
		"source_level_id": String(source_level_id),
		"target_level_id": String(target_level_id),
		"entry_id": String(entry_id),
		"player_facing": player_facing,
		"player_velocity": player_velocity,
		"camera_state": camera_state.duplicate(true),
		"custom_data": custom_data.duplicate(true),
	}

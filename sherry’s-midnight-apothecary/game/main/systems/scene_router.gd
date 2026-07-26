class_name SceneRouter
extends Node

## Compatibility boundary over GameRoot's existing dual-viewport transition.
## Business scenes call this interface; the transition implementation remains in GameRoot.

signal change_requested(target_level_id: StringName, entry_id: StringName, transition_data: Dictionary)

var is_changing := false
var last_request: Dictionary = {}

func change_level(target_level_id: StringName, entry_id: StringName = &"default", transition_data: Dictionary = {}) -> bool:
	var host := get_parent()
	if target_level_id.is_empty() or is_changing:
		return false
	if host != null and String(host.get("current_scene_key")) == String(target_level_id):
		return false
	last_request = {
		"target_level_id": target_level_id,
		"entry_id": entry_id,
		"transition_data": transition_data.duplicate(true),
	}
	change_requested.emit(target_level_id, entry_id, transition_data)
	if host != null and host.has_method("transition_to_destination"):
		is_changing = true
		host.call("transition_to_destination", String(target_level_id))
		return true
	return false

func complete_change() -> void:
	is_changing = false

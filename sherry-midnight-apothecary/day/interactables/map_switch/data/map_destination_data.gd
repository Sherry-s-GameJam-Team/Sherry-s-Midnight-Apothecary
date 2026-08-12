class_name MapDestinationData
extends Resource

## Optional typed source for callers that do not already have a location registry.
@export var id: StringName
@export var display_name := ""
@export var subtitle := ""
@export var map_pos := Vector2.ZERO
@export var danger := ""
@export var distance_text := ""
@export var environment := ""
@export_multiline var description := ""

func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"subtitle": subtitle,
		"pos": map_pos,
		"danger": danger,
		"distance": distance_text,
		"environment": environment,
		"description": description,
	}

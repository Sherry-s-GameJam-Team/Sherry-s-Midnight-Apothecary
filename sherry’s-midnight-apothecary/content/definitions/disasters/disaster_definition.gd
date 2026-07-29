class_name DisasterDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var description: String
@export var affected_region_ids: Array[StringName] = []
@export var gameplay_modifiers: Dictionary = {}
@export var recovery_story_flag_id: StringName


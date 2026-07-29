class_name LevelDefinition
extends Resource

@export var id: StringName
@export var level_id: StringName:
	get:
		return id
	set(value):
		id = value
@export var display_name: String
@export var region_id: StringName
@export var content_scene: PackedScene
@export var default_entry_id: StringName
@export var music_id: StringName
@export var environment_profile_id: StringName
@export var native_ingredient_ids: Array[StringName] = []

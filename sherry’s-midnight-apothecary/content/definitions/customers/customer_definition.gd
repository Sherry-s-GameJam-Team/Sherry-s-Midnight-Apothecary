class_name CustomerDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var portrait: Texture2D
@export var request_ids: Array[StringName] = []
@export var relationship_tiers: Dictionary = {}
@export var story_flag_requirements: Array[StringName] = []


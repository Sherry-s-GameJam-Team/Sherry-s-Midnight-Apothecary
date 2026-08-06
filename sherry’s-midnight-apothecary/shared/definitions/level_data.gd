class_name LevelData
extends Resource

@export var id: StringName
@export var display_name: String
@export var disaster_name: String = "灾难未定"
@export_multiline var scene_description: String = "场景描述待补充"
@export var content_scene: PackedScene
@export var default_entry_id: StringName
@export var native_ingredient_ids: Array[StringName] = []

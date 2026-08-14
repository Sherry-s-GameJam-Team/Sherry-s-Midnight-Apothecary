class_name LevelData
extends Resource

@export var id: StringName
@export var display_name: String
@export var disaster_name: String = "灾难未定"
@export_multiline var normal_description: String = "场景描述待补充"
## Legacy alias kept so older LevelData resources continue to load.
@export_multiline var scene_description: String = ""
@export var disaster_days: Array[int] = []
@export var content_scene: PackedScene
@export var default_entry_id: StringName
@export var show_title_card := true
@export var native_ingredient_ids: Array[StringName] = []


func is_disaster_day(day: int) -> bool:
	return disaster_days.has(day)


func title_subtitle_for_day(day: int) -> String:
	if is_disaster_day(day):
		return disaster_name
	return normal_description if not normal_description.is_empty() else scene_description

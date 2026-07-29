class_name DayDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export_range(1, 30, 1) var day := 1
@export var level_id: StringName
@export var disaster_id: StringName
@export var story_event_ids: Array[StringName] = []
@export var customer_pool_ids: Array[StringName] = []
@export var enemy_modifiers: Dictionary = {}
@export var harvest_modifiers: Dictionary = {}
@export var economy_modifiers: Dictionary = {}
@export var is_final_day := false


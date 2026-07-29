class_name EnemyDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var max_health := 1
@export var behavior_id: StringName
@export var drop_table: Dictionary = {}
@export var tags: Array[StringName] = []


class_name StoryEventDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var required_flags: Array[StringName] = []
@export var blocked_flags: Array[StringName] = []
@export var resulting_flags: Array[StringName] = []
@export var priority := 0


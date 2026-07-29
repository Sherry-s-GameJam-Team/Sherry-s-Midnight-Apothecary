class_name CustomerRequestDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var customer_id: StringName
@export var accepted_potion_ids: Array[StringName] = []
@export var required_tags: Array[StringName] = []
@export var reward_money := 0
@export var relationship_change := 0


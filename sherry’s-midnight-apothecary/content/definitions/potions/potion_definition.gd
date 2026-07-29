class_name PotionDefinition
extends Resource

@export var id: StringName
@export var potion_id: StringName:
	get:
		return id
	set(value):
		id = value
@export var display_name: String
@export var color_id: StringName
@export var concentration := 0
@export var quality := 0
@export var combat_effect_id: StringName
@export var shop_effect_id: StringName
@export var sell_value := 0
@export var icon: Texture2D

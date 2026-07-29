class_name IngredientDefinition
extends Resource

@export var id: StringName
@export var ingredient_id: StringName:
	get:
		return id
	set(value):
		id = value
@export var display_name: String
@export var color_id: StringName
@export var base_concentration := 0
@export var quality := 0
@export var tags: Array[StringName] = []
@export var base_value := 0
@export var icon: Texture2D

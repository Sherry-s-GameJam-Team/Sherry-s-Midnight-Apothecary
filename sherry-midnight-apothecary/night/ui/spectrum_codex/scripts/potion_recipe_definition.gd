class_name PotionRecipeDefinition
extends Resource

@export var id: StringName = &""
@export var function_id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var primary_tag: StringName = &""
@export var secondary_tag: StringName = &""
@export var matrix_row: int = 0
@export var matrix_col: int = 0
@export var icon: Texture2D
@export var is_special: bool = false
@export var unlock_hint: String = ""

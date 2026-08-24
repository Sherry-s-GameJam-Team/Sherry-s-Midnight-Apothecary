class_name PotionEffectCombination
extends Resource

@export var id: StringName = &""
@export var display_name := ""
@export_multiline var description := ""
@export var primary_effect_id: StringName = &""
@export var secondary_effect_id: StringName = &""
@export_range(0, 6, 1) var matrix_row := 0
@export_range(0, 6, 1) var matrix_col := 0


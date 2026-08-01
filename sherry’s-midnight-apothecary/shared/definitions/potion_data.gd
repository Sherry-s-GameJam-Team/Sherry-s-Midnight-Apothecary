class_name PotionData
extends Resource

@export var id: StringName
@export var display_name: String
@export var color_name: String
@export var display_color := Color.WHITE
@export var main_effect_id: StringName
@export_range(0.0, 1.0) var spectrum_center_x := 0.5
@export var effect_ranges: Array[Vector2] = []
@export var base_price := 0
@export var icon: Texture2D
@export var heat_profile: HeatProfileData

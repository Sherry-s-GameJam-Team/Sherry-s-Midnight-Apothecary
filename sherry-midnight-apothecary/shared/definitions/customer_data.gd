class_name CustomerData
extends Resource

@export var id: StringName
@export var display_name: String
@export var portrait: Texture2D
@export var preferred_potion_ids: Array[StringName] = []
@export var request_text: String
@export_range(0.1, 3.0, 0.05) var price_multiplier := 1.0

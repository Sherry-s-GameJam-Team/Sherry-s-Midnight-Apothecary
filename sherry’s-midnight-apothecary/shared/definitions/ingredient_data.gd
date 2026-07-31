class_name IngredientData
extends Resource

@export var id: StringName
@export var display_name: String
@export var english_name: String
@export_multiline var description: String
@export_multiline var lore: String
@export var icon: Texture2D
@export var preview_texture: Texture2D
@export var reference_canvas_size := Vector2i.ZERO
@export var production_layers: Array[HerbColorLayerData] = []
@export var base_value := 0
@export_range(0.0, 1.0) var spectrum_start := 0.0
@export_range(0.0, 1.0) var spectrum_end := 1.0
@export_range(0.0, 2.0) var base_quality := 1.0
@export_range(0.0, 2.0) var base_concentration := 1.0

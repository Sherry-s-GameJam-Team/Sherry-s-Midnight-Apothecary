class_name HerbColorLayerData
extends Resource

@export var id: StringName
@export var display_name: String
@export var color_id: StringName
@export var display_color := Color.WHITE
@export_range(0.0, 1.0) var spectrum_x := 0.5
@export_range(0.0, 2.0) var layer_yield_multiplier := 1.0
@export var pieces: Array[HerbPieceData] = []

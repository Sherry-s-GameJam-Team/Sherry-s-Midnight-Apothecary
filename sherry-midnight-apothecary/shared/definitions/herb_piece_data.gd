class_name HerbPieceData
extends Resource

enum Kind {
	FRUIT,
	FOLIAGE,
	OTHER,
}

@export var id: StringName
@export var display_name: String
@export var kind := Kind.OTHER
@export var texture: Texture2D
@export var source_rect := Rect2i()
@export var area_ratio := 0.0
@export var detachable := true
@export var grindable := true
@export var color_id: StringName
@export_range(0.0, 1.0) var spectrum_x := 0.5
@export var display_color := Color.WHITE
@export_range(0.0, 2.0) var yield_multiplier := 1.0
@export_range(0.0, 2.0) var quality_multiplier := 1.0
@export_range(0.0, 2.0) var concentration_multiplier := 1.0
@export var z_order := 0
@export var pickup_anchor_normalized := Vector2(0.5, 0.5)


func effective_yield() -> float:
	return maxf(area_ratio * yield_multiplier, 0.0)

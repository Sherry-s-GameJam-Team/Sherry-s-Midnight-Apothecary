extends Node2D

const VARIANT_TEXTURE := preload("res://examples/re2.png")
const BASE_SOURCE_ID := 3
const VARIANT_SOURCE_ID := 4
const COLLISION_TERRAIN := 1
const TILE_SIZE := Vector2(32, 32)


func _enter_tree() -> void:
	var beach := get_node_or_null("Beach") as TileMapLayer
	if beach == null or beach.tile_set == null or beach.tile_set.has_source(VARIANT_SOURCE_ID):
		return

	var base_atlas := beach.tile_set.get_source(BASE_SOURCE_ID) as TileSetAtlasSource
	if base_atlas == null:
		push_warning("Beach TileSet is missing its base texture atlas.")
		return

	# The duplicate retains every terrain-peering rule, so TileMapDual can choose
	# either atlas for the same terrain configuration using its seeded RNG.
	var variant_atlas := base_atlas.duplicate(true) as TileSetAtlasSource
	variant_atlas.texture = VARIANT_TEXTURE
	beach.tile_set.add_source(variant_atlas, VARIANT_SOURCE_ID)


func _ready() -> void:
	var beach := get_node_or_null("Beach") as TileMapLayer
	if beach == null:
		return

	var collision_body := StaticBody2D.new()
	collision_body.name = "BeachTileCollisions"
	beach.add_child(collision_body)

	var tile_shape := RectangleShape2D.new()
	tile_shape.size = TILE_SIZE
	for cell in beach.get_used_cells():
		var tile_data := beach.get_cell_tile_data(cell)
		if tile_data == null or tile_data.terrain != COLLISION_TERRAIN:
			continue
		var collision_shape := CollisionShape2D.new()
		collision_shape.position = beach.map_to_local(cell)
		collision_shape.shape = tile_shape
		collision_body.add_child(collision_shape)

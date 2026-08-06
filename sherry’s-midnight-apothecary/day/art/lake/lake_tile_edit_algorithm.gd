@tool
extends Node

const FULL_TERRAIN_TILE := Vector2i(2, 1)
const EMPTY_TERRAIN_TILE := Vector2i(0, 3)
const CORNER_NEIGHBORS := [
	TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
	TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
]

const TERRAIN_RULES := {
	Vector2i(0, 3): [0, 0, 0, 0], Vector2i(3, 3): [0, 0, 1, 0],
	Vector2i(0, 2): [0, 0, 0, 1], Vector2i(1, 2): [0, 0, 1, 1],
	Vector2i(0, 0): [0, 1, 0, 0], Vector2i(3, 2): [0, 1, 1, 0],
	Vector2i(2, 3): [0, 1, 0, 1], Vector2i(3, 1): [0, 1, 1, 1],
	Vector2i(1, 3): [1, 0, 0, 0], Vector2i(0, 1): [1, 0, 1, 0],
	Vector2i(1, 0): [1, 0, 0, 1], Vector2i(2, 2): [1, 0, 1, 1],
	Vector2i(3, 0): [1, 1, 0, 0], Vector2i(2, 0): [1, 1, 1, 0],
	Vector2i(1, 1): [1, 1, 0, 1], Vector2i(2, 1): [1, 1, 1, 1],
}


func _enter_tree() -> void:
	var surface := get_parent().get_node_or_null("TileEditSurface") as TileMapLayer
	if surface == null or surface.tile_set == null:
		return

	for source_index in surface.tile_set.get_source_count():
		var source_id := surface.tile_set.get_source_id(source_index)
		var atlas := surface.tile_set.get_source(source_id) as TileSetAtlasSource
		if atlas == null:
			continue
		_configure_atlas(atlas)


func _configure_atlas(atlas: TileSetAtlasSource) -> void:
	for tile in TERRAIN_RULES:
		var data := atlas.get_tile_data(tile, 0)
		data.terrain_set = 0
		if tile == EMPTY_TERRAIN_TILE:
			data.terrain = 0
		elif tile == FULL_TERRAIN_TILE:
			data.terrain = 1
		else:
			data.terrain = -1
		var bits: Array = TERRAIN_RULES[tile]
		for index in CORNER_NEIGHBORS.size():
			data.set_terrain_peering_bit(CORNER_NEIGHBORS[index], bits[index])

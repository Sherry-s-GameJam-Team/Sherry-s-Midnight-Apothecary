extends RefCounted

const ALCHEMY_SCENE := preload("res://night/alchemy/alchemy_runtime.tscn")

const EXPECTED_COLORS := {
	&"chalice_ice_spire": &"blue",
	&"tundra_snow_whisk": &"blue",
	&"vesper_blue_thicket": &"blue",
	&"dusk_water_opuntia": &"purple",
	&"stagnant_breeze_bell_vine": &"purple",
	&"slumber_marrow_geode": &"purple",
	&"drop_cliff_whistle_leaf": &"yellow",
	&"eyrie_nest_seed_ball": &"yellow",
	&"wind_cutter_rye": &"yellow",
	&"egg_climbers_honey_pot": &"yellow",
}


static func run(test: TestSupport) -> void:
	var runtime := ALCHEMY_SCENE.instantiate() as AlchemyRuntime
	test.expect(runtime != null, "Alchemy runtime loads with the colored plant library.")
	if runtime == null:
		return
	var total_piece_count := 0
	var seen_ids: Dictionary = {}
	for ingredient: IngredientData in runtime.ingredients:
		if ingredient == null:
			continue
		test.expect(not seen_ids.has(ingredient.id), "Ingredient IDs stay unique after colored plant import: %s" % ingredient.id)
		seen_ids[ingredient.id] = true
		if not EXPECTED_COLORS.has(ingredient.id):
			continue
		var expected_color: StringName = EXPECTED_COLORS[ingredient.id]
		test.expect_equal(ingredient.reference_canvas_size, Vector2i(4096, 4096), "%s keeps the source canvas coordinates." % ingredient.id)
		test.expect(ingredient.icon != null and ingredient.preview_texture != null, "%s provides inventory and preview artwork." % ingredient.id)
		test.expect_equal(ingredient.production_layers.size(), 1, "%s has one source color layer." % ingredient.id)
		if ingredient.production_layers.is_empty():
			continue
		var layer: HerbColorLayerData = ingredient.production_layers[0]
		test.expect_equal(layer.color_id, expected_color, "%s uses its folder color ID." % ingredient.id)
		for piece: HerbPieceData in layer.pieces:
			total_piece_count += 1
			test.expect(piece.texture != null, "%s piece texture loads." % piece.id)
			test.expect(piece.source_rect.size.x > 0 and piece.source_rect.size.y > 0, "%s keeps a valid alpha-trimmed source rectangle." % piece.id)
			test.expect_equal(piece.color_id, expected_color, "%s inherits the plant color ID." % piece.id)
			if expected_color == &"yellow":
				test.expect(piece.spectrum_x >= 0.2857 and piece.spectrum_x <= 0.4285, "%s stays inside the yellow band." % piece.id)
			elif expected_color == &"blue":
				test.expect(piece.spectrum_x >= 0.7142 and piece.spectrum_x <= 0.8571, "%s stays inside the blue band." % piece.id)
			else:
				test.expect(piece.spectrum_x >= 0.8571 and piece.spectrum_x <= 1.0, "%s stays inside the purple band." % piece.id)
	for ingredient_id: StringName in EXPECTED_COLORS:
		test.expect(seen_ids.has(ingredient_id), "Colored plant is registered in AlchemyRuntime: %s" % ingredient_id)
	test.expect_equal(total_piece_count, 31, "All supplied colored plant parts are registered for production.")
	runtime.free()

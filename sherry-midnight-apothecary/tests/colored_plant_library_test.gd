extends RefCounted

const ALCHEMY_SCENE := preload("res://night/alchemy/alchemy_runtime.tscn")

const EXPECTED_COLORS := {
	&"maple_heart_dark_vein": &"red",
	&"maple_marrow_star_crystal": &"red",
	&"waystation_lantern_fruit": &"red",
	&"sun_etched_flower": &"orange",
	&"hanging_lantern_bell_cap": &"orange",
	&"morning_wheel_crystal_crown": &"orange",
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
	&"returning_tide_thorn_fern": &"cyan",
	&"tideplate_lotus": &"cyan",
	&"tide_lantern_flower": &"cyan",
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
			elif expected_color == &"red":
				test.expect(piece.spectrum_x >= 0.0 and piece.spectrum_x <= 0.1428, "%s stays inside the red band." % piece.id)
			elif expected_color == &"orange":
				test.expect(piece.spectrum_x >= 0.1428 and piece.spectrum_x <= 0.2857, "%s stays inside the orange band." % piece.id)
			elif expected_color == &"blue":
				test.expect(piece.spectrum_x >= 0.7142 and piece.spectrum_x <= 0.8571, "%s stays inside the blue band." % piece.id)
			elif expected_color == &"cyan":
				test.expect(piece.spectrum_x >= 0.5714 and piece.spectrum_x <= 0.7142, "%s stays inside the cyan band." % piece.id)
			else:
				test.expect(piece.spectrum_x >= 0.8571 and piece.spectrum_x <= 1.0, "%s stays inside the purple band." % piece.id)
	for ingredient_id: StringName in EXPECTED_COLORS:
		test.expect(seen_ids.has(ingredient_id), "Colored plant is registered in AlchemyRuntime: %s" % ingredient_id)
		var herb_scene_path := "res://day/interactables/herb/herbs/%s/%s_herb.tscn" % [ingredient_id, ingredient_id]
		test.expect(ResourceLoader.exists(herb_scene_path), "Colored plant has an independently instantiable field scene: %s" % ingredient_id)
	test.expect_equal(total_piece_count, 58, "All supplied colored plant parts are registered for production.")
	var level_ingredient_expectations := {
		"res://day/levels/golden_cliff/golden_cliff_level.tres": [&"drop_cliff_whistle_leaf", &"eyrie_nest_seed_ball", &"wind_cutter_rye", &"egg_climbers_honey_pot"],
		"res://day/levels/lake_bottom/lake_bottom_level.tres": [&"returning_tide_thorn_fern", &"tideplate_lotus", &"tide_lantern_flower"],
		"res://day/levels/Crimson Vale/crimson_vale_level.tres": [&"maple_heart_dark_vein", &"maple_marrow_star_crystal", &"waystation_lantern_fruit"],
		"res://day/levels/Aurem Clockyard/aurem_clockyard_level.tres": [&"sun_etched_flower", &"hanging_lantern_bell_cap", &"morning_wheel_crystal_crown"],
		"res://day/levels/Vespervale/vespervale_garden_level.tres": [&"dusk_water_opuntia", &"vesper_blue_thicket"],
		"res://day/levels/Vespervale/vespervale_inner_level.tres": [&"stagnant_breeze_bell_vine", &"slumber_marrow_geode"],
		"res://day/levels/cliff/cliff_level.tres": [&"tundra_snow_whisk"],
		"res://day/levels/lake/lake_cliff_underwater_level.tres": [&"chalice_ice_spire"],
	}
	for level_path: String in level_ingredient_expectations:
		var level := load(level_path) as LevelData
		test.expect(level != null, "Plant-bearing level definition loads: %s" % level_path)
		if level != null:
			for ingredient_id: StringName in level_ingredient_expectations[level_path]:
				test.expect(level.native_ingredient_ids.has(ingredient_id), "Level advertises its fixed native plant: %s" % ingredient_id)
	runtime.free()

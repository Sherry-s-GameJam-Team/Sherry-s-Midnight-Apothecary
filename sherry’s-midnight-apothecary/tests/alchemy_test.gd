extends RefCounted

const ALCHEMY_SCENE := preload("res://night/alchemy/alchemy_runtime.tscn")


static func run(test: TestSupport) -> void:
	var runtime := ALCHEMY_SCENE.instantiate() as AlchemyRuntime
	var scene_tree := Engine.get_main_loop() as SceneTree
	scene_tree.root.add_child(runtime)
	var player := PlayerData.new()
	player.inventory = {&"herdsmans_loaf_bush": 4}
	var result := NightResult.new()
	runtime.setup(player, result, 3)

	test.expect_equal(runtime.available_count(&"herdsmans_loaf_bush"), 4, "Alchemy reads base inventory.")
	test.expect(runtime.reserve_ingredient(&"herdsmans_loaf_bush"), "An available herb can be reserved.")
	test.expect_equal(runtime.available_count(&"herdsmans_loaf_bush"), 3, "Current batch reservation reduces available inventory.")
	test.expect_equal(result.spent_ingredients.size(), 0, "Reservation does not commit NightResult spending.")
	runtime.cancel_batch()
	test.expect_equal(runtime.available_count(&"herdsmans_loaf_bush"), 4, "Cancel restores uncommitted inventory.")

	test.expect(runtime.reserve_ingredient(&"herdsmans_loaf_bush"), "A herb can be reserved after cancel.")
	var original_concentration := runtime.processing_ingredient.concentration
	var original_quality := runtime.processing_ingredient.quality
	test.expect(runtime.set_processing_selection(0.40, 0.46), "Cutting accepts a valid sub-range.")
	test.expect_float_close(runtime.processing_ingredient.spectrum_x, 0.43, 0.001, "Cutting changes the spectrum center.")
	test.expect(runtime.apply_tool(&"grind"), "Grinding applies once.")
	test.expect(runtime.processing_ingredient.concentration > original_concentration, "Grinding raises concentration.")
	test.expect(runtime.processing_ingredient.quality < original_quality, "Grinding lowers quality.")
	test.expect(not runtime.apply_tool(&"grind"), "Grinding cannot be repeated.")
	test.expect(runtime.apply_tool(&"distill"), "Distilling applies once.")
	test.expect(runtime.apply_tool(&"dilute"), "Diluting applies.")
	test.expect(runtime.add_processing_to_cauldron(), "Processed herb enters the cauldron.")
	var prediction := runtime.calculate_prediction()
	test.expect_equal(prediction.get("potion_id"), &"green_potion", "A hit in green's first non-contiguous range produces green potion.")
	var inventory_before := player.inventory.duplicate(true)
	var first := runtime.brew()
	test.expect(not first.is_empty(), "A valid batch produces an instance.")
	test.expect_equal(player.inventory, inventory_before, "Brewing does not directly mutate PlayerData inventory.")
	test.expect_equal(result.spent_ingredients.get(&"herdsmans_loaf_bush"), 1, "Committed batch records one ingredient exactly once.")
	test.expect_equal(result.produced_potions[&"green_potion"].size(), 1, "Committed batch appends a dynamic potion instance.")

	test.expect(runtime.reserve_ingredient(&"herdsmans_loaf_bush"), "A second batch can start in the same night.")
	test.expect(runtime.set_processing_selection(0.40, 0.46), "Second batch can be cut.")
	test.expect(runtime.add_processing_to_cauldron(), "Second batch ingredient enters cauldron.")
	test.expect(not runtime.brew().is_empty(), "Second batch brews.")
	test.expect_equal(result.spent_ingredients.get(&"herdsmans_loaf_bush"), 2, "Two committed batches spend two, without double subtraction.")
	test.expect_equal(result.produced_potions[&"green_potion"].size(), 2, "Two potion instances are preserved.")

	test.expect(runtime.reserve_ingredient(&"herdsmans_loaf_bush"), "A failure batch can reserve an herb.")
	test.expect(runtime.set_processing_selection(0.47, 0.49), "Cutting can target the gap in green ranges.")
	test.expect(runtime.add_processing_to_cauldron(), "Failure candidate enters cauldron.")
	var failed_prediction := runtime.calculate_prediction()
	test.expect_equal(failed_prediction.get("potion_id"), &"black_potion", "A spectrum gap produces black potion.")
	test.expect(not runtime.brew().is_empty(), "Black potion is still a valid committed product.")
	test.expect_equal(result.spent_ingredients.get(&"herdsmans_loaf_bush"), 3, "Black potion still consumes its material.")
	test.expect_equal(result.produced_potions[&"black_potion"].size(), 1, "Black potion is written to production.")

	var green_component := ProcessedIngredient.from_ingredient(runtime.ingredients[0])
	green_component.spectrum_x = 0.43
	green_component.extraction_ratio = 0.60
	green_component.concentration = 1.0
	var blue_component := ProcessedIngredient.from_ingredient(runtime.ingredients[0])
	blue_component.spectrum_x = 0.73
	blue_component.extraction_ratio = 0.40
	blue_component.concentration = 1.0
	runtime.cauldron_ingredients.assign([green_component, blue_component])
	test.expect(runtime.temperature_control != null, "Alchemy exposes the rotating temperature gauge.")
	runtime.set_temperature(0.0)
	var cold_angle := runtime.temperature_control.needle_angle_degrees()
	runtime.set_temperature(50.0)
	var middle_angle := runtime.temperature_control.needle_angle_degrees()
	runtime.set_temperature(100.0)
	var hot_angle := runtime.temperature_control.needle_angle_degrees()
	test.expect(cold_angle < middle_angle and middle_angle < hot_angle, "Temperature rotates the gauge needle across its full arc.")
	runtime.set_temperature(55.0)
	test.expect(runtime.bellows_button != null, "The artwork bellows has an interactive control.")
	runtime.bellows_button.pressed.emit()
	test.expect_float_close(runtime.temperature, 60.0, 0.001, "Clicking the bellows raises temperature by five degrees.")
	runtime.set_temperature(98.0)
	runtime.pump_bellows()
	test.expect_float_close(runtime.temperature, 100.0, 0.001, "Bellows heat is clamped at the gauge maximum.")
	runtime.set_temperature(55.0)
	var secondary_prediction := runtime.calculate_prediction()
	test.expect_equal(secondary_prediction.get("potion_id"), &"green_potion", "Weighted continuous color determines the main potion.")
	test.expect_equal(secondary_prediction.get("secondary_effect_id"), &"mana", "Second color contribution above 20% becomes secondary effect.")
	var ideal_quality := float(secondary_prediction.get("quality", 0.0))
	runtime.set_temperature(0.0)
	test.expect(float(runtime.calculate_prediction().get("quality", 0.0)) < ideal_quality, "Temperature outside the ideal range lowers quality.")
	runtime.cancel_batch()

	player.apply_night_result(result)
	test.expect_equal(player.inventory[&"herdsmans_loaf_bush"], 1, "PlayerData changes only when NightResult is applied.")
	test.expect_equal(player.potions[&"green_potion"].size(), 2, "Night settlement appends both dynamic potion instances.")
	test.expect_equal(player.potions[&"black_potion"].size(), 1, "Night settlement includes failed potion product.")
	runtime.free()

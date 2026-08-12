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
	var yellow_storm := load("res://shared/definitions/data/potions/yellow_potion.tres") as PotionData
	var purification := load("res://shared/definitions/data/potions/purification_potion.tres") as PotionData
	test.expect_equal(yellow_storm.display_name, "雷击与星陨之药", "The former yellow purification potion is now the lightning and meteor potion.")
	test.expect_equal(yellow_storm.main_effect_id, &"lightning_meteor", "The yellow spectrum potion uses the storm combat effect.")
	test.expect_equal(purification.main_effect_id, &"purify", "Purification is owned by the dedicated dew potion.")
	test.expect(purification.effect_ranges.is_empty(), "The dedicated purification potion cannot be reached through the ordinary spectrum.")

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
	var first := _brew_to_completion(runtime)
	test.expect(not first.is_empty(), "A valid batch produces an instance.")
	test.expect(first.has("thermal_score") and first.has("potency") and first.has("duration"), "Brewed instances persist their thermal treatment attributes.")
	test.expect_equal(player.inventory, inventory_before, "Brewing does not directly mutate PlayerData inventory.")
	test.expect_equal(result.spent_ingredients.get(&"herdsmans_loaf_bush"), 1, "Committed batch records one ingredient exactly once.")
	test.expect_equal(result.produced_potions[&"green_potion"].size(), 1, "Committed batch appends a dynamic potion instance.")

	test.expect(runtime.reserve_ingredient(&"herdsmans_loaf_bush"), "A second batch can start in the same night.")
	test.expect(runtime.set_processing_selection(0.40, 0.46), "Second batch can be cut.")
	test.expect(runtime.add_processing_to_cauldron(), "Second batch ingredient enters cauldron.")
	test.expect(not _brew_to_completion(runtime).is_empty(), "Second batch brews.")
	test.expect_equal(result.spent_ingredients.get(&"herdsmans_loaf_bush"), 2, "Two committed batches spend two, without double subtraction.")
	test.expect_equal(result.produced_potions[&"green_potion"].size(), 2, "Two potion instances are preserved.")

	test.expect(runtime.reserve_ingredient(&"herdsmans_loaf_bush"), "A failure batch can reserve an herb.")
	test.expect(runtime.set_processing_selection(0.47, 0.49), "Cutting can target the gap in green ranges.")
	test.expect(runtime.add_processing_to_cauldron(), "Failure candidate enters cauldron.")
	var failed_prediction := runtime.calculate_prediction()
	test.expect_equal(failed_prediction.get("potion_id"), &"black_potion", "A spectrum gap produces black potion.")
	test.expect(not _brew_to_completion(runtime).is_empty(), "Black potion is still a valid committed product.")
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
	test.expect(runtime.temperature_gauge != null, "Alchemy exposes the rotating temperature gauge.")
	runtime.set_temperature(0.0)
	var cold_angle := runtime.temperature_gauge.needle_angle_degrees()
	runtime.set_temperature(50.0)
	var middle_angle := runtime.temperature_gauge.needle_angle_degrees()
	runtime.set_temperature(100.0)
	var hot_angle := runtime.temperature_gauge.needle_angle_degrees()
	test.expect(cold_angle < middle_angle and middle_angle < hot_angle, "Temperature rotates the gauge needle across its full arc.")
	runtime.set_temperature(55.0)
	test.expect(runtime.bellows_control != null, "The artwork bellows has an interactive control.")
	var secondary_prediction := runtime.calculate_prediction()
	test.expect_equal(secondary_prediction.get("potion_id"), &"green_potion", "Weighted continuous color determines the main potion.")
	test.expect_equal(secondary_prediction.get("secondary_effect_id"), &"mana", "Second color contribution above 20% becomes secondary effect.")
	test.expect(float(secondary_prediction.get("quality", 0.0)) > 0.0, "Color preview remains independent of heat processing.")
	runtime.cancel_batch()
	var dew_source := runtime.ingredient_by_id(&"dew_flask_herb")
	var special_dew := ProcessedIngredient.from_ingredient(dew_source)
	special_dew.special_potion_id = &"purification_potion"
	special_dew.spectrum_x = 0.72
	special_dew.quality = 1.2
	runtime.cauldron_ingredients.assign([special_dew])
	var purification_prediction := runtime.calculate_prediction()
	test.expect_equal(purification_prediction.get("potion_id"), &"purification_potion", "Pure blue dew uses the dedicated purification recipe.")
	test.expect(bool(purification_prediction.get("special_brew", false)), "Dedicated purification is marked as a special brew.")
	var contaminant := ProcessedIngredient.from_ingredient(runtime.ingredients[0])
	runtime.cauldron_ingredients.append(contaminant)
	test.expect_equal(runtime.calculate_prediction().get("potion_id"), &"black_potion", "Mixing ordinary material into blue dew contaminates the dedicated recipe.")
	runtime.cauldron_ingredients.assign([special_dew])
	var brewed_purification := _brew_to_completion(runtime)
	test.expect_equal(brewed_purification.get("potion_id"), &"purification_potion", "Pure blue dew completes as the dedicated purification potion.")
	test.expect_equal(result.produced_potions[&"purification_potion"].size(), 1, "Dedicated purification is committed to nightly production.")

	player.apply_night_result(result)
	test.expect_equal(player.inventory[&"herdsmans_loaf_bush"], 1, "PlayerData changes only when NightResult is applied.")
	test.expect_equal(player.potions[&"green_potion"].size(), 2, "Night settlement appends both dynamic potion instances.")
	test.expect_equal(player.potions[&"black_potion"].size(), 1, "Night settlement includes failed potion product.")
	runtime.free()


static func _brew_to_completion(runtime: AlchemyRuntime) -> Dictionary:
	runtime.heat_controller.cooling_rate = 0.0
	runtime.set_temperature(50.0)
	var started := runtime.brew()
	if started.is_empty():
		return {}
	var pump_count := 0
	while runtime._distillation_fill_target < 0.999 and pump_count < 16:
		runtime.pump_bellows()
		pump_count += 1
	if runtime._distillation_fill_target < 0.999:
		return {}
	runtime.distillation_fill.stop_animation()
	runtime.distillation_fill.set_fill_progress(1.0)
	runtime._on_distillation_fill_animation_finished(1.0)
	return runtime.last_brewed_instance

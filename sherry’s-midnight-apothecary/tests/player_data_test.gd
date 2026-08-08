extends RefCounted


static func run(test: TestSupport) -> void:
	var player := PlayerData.new()
	test.expect_equal(player.equipped_potion_ids, [&"", &"", &""], "New players start with three empty potion slots.")
	var day_result := DayResult.new()
	day_result.remaining_health = 72
	day_result.collected_items = {&"herdsmans_loaf_bush": 4}
	day_result.remaining_potions = {&"healing_tonic": 1}
	day_result.unlocked_level_id = &"forest"
	player.apply_day_result(day_result)

	test.expect_equal(player.health, 72, "Day health is applied to shared player data.")
	test.expect_equal(player.inventory[&"herdsmans_loaf_bush"], 4, "Day items are applied.")
	test.expect(player.unlocked_levels.has(&"forest"), "Day level unlock is applied.")

	var night_result := NightResult.new()
	night_result.earned_money = 50
	night_result.spent_ingredients = {&"herdsmans_loaf_bush": 2}
	night_result.produced_potions = {&"blue_tonic": 2}
	night_result.sold_potions = {&"healing_tonic": 1}
	player.apply_night_result(night_result)

	test.expect_equal(player.money, 50, "Night earnings are applied.")
	test.expect_equal(player.inventory[&"herdsmans_loaf_bush"], 2, "Night ingredient costs are applied.")
	test.expect_equal(player.potions[&"blue_tonic"].size(), 2, "Night potion production is applied.")
	test.expect(not player.potions.has(&"healing_tonic"), "Sold potions are removed at zero.")
	player.add_story_item(&"sealed_letter", 2)
	player.remove_story_item(&"sealed_letter")
	test.expect_equal(player.story_items[&"sealed_letter"], 1, "Story item counts can be added and removed.")

	var restored := PlayerData.from_save_data(player.to_save_data())
	test.expect_equal(restored.health, 72, "Player health round-trips.")
	test.expect_equal(restored.inventory[&"herdsmans_loaf_bush"], 2, "Player inventory round-trips.")
	test.expect_equal(restored.potions[&"blue_tonic"].size(), 2, "Dynamic potion arrays round-trip.")
	test.expect_equal(restored.story_items[&"sealed_letter"], 1, "Story items round-trip.")
	var migrated_empty := PlayerData.from_save_data({})
	test.expect_equal(migrated_empty.equipped_potion_ids, [&"", &"", &""], "Saves without a loadout migrate to empty slots.")
	var migrated_equipped := PlayerData.from_save_data({"equipped_potion_ids": ["red_potion", "", ""]})
	test.expect_equal(migrated_equipped.equipped_potion_ids[0], &"red_potion", "Explicit saved loadouts are preserved.")
	migrated_equipped.move_equip_potion(2, &"red_potion")
	test.expect_equal(migrated_equipped.equipped_potion_ids, [&"", &"", &"red_potion"], "Equipped potion types move without duplication.")
	player.remove_story_item(&"sealed_letter")
	test.expect(not player.story_items.has(&"sealed_letter"), "Story items are erased when their count reaches zero.")
	player.tutorial_flags["potion_throw_controls_shown"] = true
	player.tutorial_flags["throw_diagram_seen"] = true
	var tutorial_restored := PlayerData.from_save_data(player.to_save_data())
	test.expect(bool(tutorial_restored.tutorial_flags.get("throw_diagram_seen", false)), "Tutorial flags round-trip with PlayerData saves.")
	restored.inventory[&"herdsmans_loaf_bush"] = 99
	test.expect_equal(player.inventory[&"herdsmans_loaf_bush"], 2, "Restored dictionaries do not alias the source.")

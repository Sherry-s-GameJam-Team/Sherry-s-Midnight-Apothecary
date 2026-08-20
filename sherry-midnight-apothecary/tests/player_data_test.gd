extends RefCounted


static func run(test: TestSupport) -> void:
	var player := PlayerData.new()
	test.expect_equal(player.store_reputation, 100, "New players begin with full store reputation.")
	test.expect_equal(player.debt, 30000, "New players visibly begin with 30000曜 of debt.")
	test.expect(player.potions.is_empty(), "New players start without any potions.")
	test.expect_equal(player.equipped_potion_ids, [&"", &"", &""], "New players start with three empty potion slots.")
	var health_updates: Array[Vector2i] = []
	var depleted_events: Array[bool] = []
	player.health_changed.connect(func(current: int, maximum: int) -> void: health_updates.append(Vector2i(current, maximum)))
	player.health_depleted.connect(func() -> void: depleted_events.append(true))
	test.expect_equal(player.apply_damage(15), 15, "PlayerData applies bounded global damage.")
	test.expect_equal(player.health, 85, "Damage lowers global health.")
	test.expect_equal(player.restore_health(8), 8, "PlayerData restores health through the shared API.")
	test.expect_equal(player.health, 93, "Healing raises global health.")
	player.apply_damage(999)
	test.expect_equal(player.health, 0, "Damage clamps health at zero.")
	test.expect_equal(depleted_events.size(), 1, "Reaching zero emits one depletion signal.")
	player.restore_full_health()
	test.expect_equal(player.health, player.max_health, "Full recovery restores maximum health.")
	test.expect(not health_updates.is_empty(), "Health mutations emit HUD update data.")
	var rollback_snapshot := player.to_save_data()
	player.money = 999
	player.inventory[&"temporary"] = 3
	player.apply_damage(40)
	player.restore_from_save_data(rollback_snapshot)
	test.expect_equal(player.money, 0, "Snapshot restoration rolls back transient money.")
	test.expect(not player.inventory.has(&"temporary"), "Snapshot restoration rolls back transient inventory.")
	test.expect_equal(player.health, player.max_health, "Snapshot restoration restores saved health.")
	var day_result := DayResult.new()
	day_result.remaining_health = 72
	day_result.collected_items = {&"herdsmans_loaf_bush": 4}
	day_result.remaining_potions = {&"healing_tonic": 1}
	day_result.unlocked_level_id = &"forest"
	player.apply_day_result(day_result)

	test.expect_equal(player.health, 72, "Day health is applied to shared player data.")
	test.expect_equal(player.inventory[&"herdsmans_loaf_bush"], 4, "Day items are applied.")
	test.expect(player.unlocked_levels.has(&"forest"), "Day level unlock is applied.")
	test.expect(player.set_active_home_destination(&"grassland"), "Grassland is unlocked from the start.")
	test.expect(not player.set_active_home_destination(&"golden_cliff"), "Locked levels cannot become the active Home destination.")
	test.expect(player.unlock_level(&"golden_cliff"), "Travel anchors can unlock a new level.")
	test.expect(not player.unlock_level(&"forest"), "Already unlocked levels are not duplicated.")
	test.expect(player.set_active_home_destination(&"forest"), "Unlocked levels can become the active Home destination.")
	test.expect_equal(player.active_home_destination_id, &"forest", "The active Home destination is retained.")

	var night_result := NightResult.new()
	night_result.earned_money = 50
	night_result.spent_ingredients = {&"herdsmans_loaf_bush": 2}
	night_result.produced_potions = {&"blue_tonic": 2}
	night_result.sold_potions = {&"healing_tonic": 1}
	night_result.reputation_delta = -10
	player.apply_night_result(night_result)

	test.expect_equal(player.money, 50, "Night earnings are applied.")
	test.expect_equal(player.inventory[&"herdsmans_loaf_bush"], 2, "Night ingredient costs are applied.")
	test.expect_equal(player.potions[&"blue_tonic"].size(), 2, "Night potion production is applied.")
	test.expect(not player.potions.has(&"healing_tonic"), "Sold potions are removed at zero.")
	test.expect_equal(player.store_reputation, 90, "Night reputation changes are applied to shared player data.")
	player.add_story_item(&"sealed_letter", 2)
	player.remove_story_item(&"sealed_letter")
	test.expect_equal(player.story_items[&"sealed_letter"], 1, "Story item counts can be added and removed.")
	player.potions[&"yellow_potion"] = [
		{"instance_uid": "yellow-full", "remaining_dose": 1.0, "bottle_style_id": "moon", "custom_name": "月光药"},
		{"instance_uid": "yellow-partial", "remaining_dose": 0.25},
		{"instance_uid": "yellow-empty", "remaining_dose": 0.0},
	]
	test.expect_equal(player.potion_count(&"yellow_potion"), 2, "Dialogue potion count includes non-empty full and partial bottles.")
	test.expect_float_close(player.potion_dose(&"yellow_potion"), 1.25, 0.001, "Dialogue potion dose totals remaining liquid.")
	test.expect(player.has_potion(&"yellow_potion", 2), "Dialogue potion predicate accepts a minimum bottle count.")
	test.expect(not player.has_potion(&"yellow_potion", 3), "Dialogue potion predicate rejects an insufficient bottle count.")
	test.expect_equal(player.potion_count(&"missing_potion"), 0, "Dialogue potion count safely handles unknown IDs.")

	var restored := PlayerData.from_save_data(player.to_save_data())
	test.expect_equal(restored.health, 72, "Player health round-trips.")
	test.expect_equal(restored.inventory[&"herdsmans_loaf_bush"], 2, "Player inventory round-trips.")
	test.expect_equal(restored.potions[&"blue_tonic"].size(), 2, "Dynamic potion arrays round-trip.")
	test.expect_equal(restored.story_items[&"sealed_letter"], 1, "Story items round-trip.")
	test.expect_equal(restored.potions[&"yellow_potion"][0]["bottle_style_id"], "moon", "Bottle style round-trips.")
	test.expect_equal(restored.potions[&"yellow_potion"][0]["custom_name"], "月光药", "Custom potion names round-trip.")
	test.expect_equal(restored.store_reputation, 90, "Store reputation round-trips.")
	test.expect_equal(restored.active_home_destination_id, &"forest", "The active Home destination round-trips.")
	var migrated_empty := PlayerData.from_save_data({})
	test.expect_equal(migrated_empty.debt, 30000, "Legacy saves without debt adopt the 30000曜 starting debt.")
	test.expect(migrated_empty.unlocked_levels.has(&"grassland"), "Legacy saves receive the default Grassland anchor.")
	var migrated_old_debt := PlayerData.from_save_data({"version": 5, "debt": 0})
	test.expect_equal(migrated_old_debt.debt, 30000, "Version 5 saves migrate their placeholder debt to 30000曜.")
	test.expect_equal(migrated_old_debt.store_reputation, 100, "Older saves migrate to full store reputation.")
	var restored_paid_debt := PlayerData.from_save_data({"version": PlayerData.SAVE_VERSION, "debt": 12500})
	test.expect_equal(restored_paid_debt.debt, 12500, "Current saves preserve debt repayment progress.")
	test.expect_equal(migrated_empty.equipped_potion_ids, [&"", &"", &""], "Saves without a loadout migrate to empty slots.")
	var legacy_bottle := PlayerData.from_save_data({"potions": {"green_potion": [{"instance_uid": "legacy"}]}})
	test.expect_equal(legacy_bottle.potions[&"green_potion"][0]["bottle_style_id"], "health", "Legacy potions receive the default bottle style.")
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

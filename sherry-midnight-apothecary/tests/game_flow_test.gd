extends RefCounted


static func run(test: TestSupport) -> void:
	var runtime_slot := Node.new()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(runtime_slot)
	var flow := GameFlow.new()
	var player := PlayerData.new()
	player.potions[&"yellow_potion"] = [{"instance_uid": "stale-potion", "remaining_dose": 1.0}]
	player.equipped_potion_ids[0] = &"yellow_potion"
	flow.configure(runtime_slot, player)

	test.expect(flow.start_new_game(), "A new game starts in the day runtime.")
	test.expect_equal(flow.current_day, 0, "A new game starts on day zero.")
	test.expect(player.potions.is_empty(), "A new game starts without any potions.")
	test.expect_equal(player.equipped_potion_ids, [&"", &"", &""], "A new game starts with empty potion slots.")
	test.expect(flow.current_runtime is DayRuntime, "DayRuntime is active.")
	test.expect_equal((flow.current_runtime as DayRuntime).current_level.id, &"market", "Day zero keeps the first daily level in the rotation.")
	test.expect(flow.current_runtime.player_data == player, "DayRuntime receives the shared PlayerData instance.")
	player.inventory[&"unsaved_day_item"] = 2
	player.apply_damage(30)
	test.expect(flow.restart_day_after_death(), "DayFlow can rebuild the current day from its start snapshot.")
	test.expect_equal(flow.current_day, 0, "Death recovery keeps the same day number.")
	test.expect(not player.inventory.has(&"unsaved_day_item"), "Death recovery discards unsaved day inventory.")
	test.expect_equal(player.health, player.max_health, "Day-start snapshot restores the original health before revival.")
	var emitted_day_result := DayResult.new()
	emitted_day_result.remaining_health = 95
	(flow.current_runtime as DayRuntime).finish_day(emitted_day_result)
	test.expect(flow.current_runtime is NightRuntime, "A DayRuntime completion signal can safely transition to night.")
	test.expect_equal(player.health, 95, "Signal-driven daytime completion applies its result.")
	test.expect(flow.resume_game(0, GameFlow.Mode.DAY), "The signal-driven transition can rebuild day-zero mode.")
	test.expect(flow.resume_game(0, GameFlow.Mode.DAY), "Resuming the current mode rebuilds its runtime.")
	test.expect_equal(flow.current_day, 0, "Same-mode resume restores the requested day.")
	test.expect(flow.current_runtime.player_data == player, "A rebuilt runtime still receives shared PlayerData.")

	player.potions[&"yellow_potion"] = [{"instance_uid": "story-skip-potion", "remaining_dose": 0.75}]
	var skip_result := DayResult.new()
	skip_result.remaining_health = 73
	skip_result.remaining_potions = player.potions.duplicate(true)
	test.expect(flow.resume_game(4, GameFlow.Mode.DAY, &"aurem_vespervale_transition"), "The Day 4 transition level can be resumed.")
	(flow.current_runtime as DayRuntime).finish_day_skipping_night(skip_result, &"vespervale_garden")
	test.expect_equal(flow.current_day, 5, "Story night skip advances Day 4 directly to Day 5.")
	test.expect_equal(flow.current_mode, GameFlow.Mode.DAY, "Story night skip never creates NightRuntime.")
	test.expect(flow.current_runtime is DayRuntime, "Story night skip rebuilds DayRuntime.")
	test.expect_equal((flow.current_runtime as DayRuntime).current_level.id, &"vespervale_garden", "Story night skip loads the Vespervale Garden opening.")
	test.expect(player.has_event_flag(&"night_skipped_by_story"), "Story night skip persists its event marker.")
	test.expect_equal(player.health, 73, "Story night skip preserves the DayResult health.")
	test.expect(player.potions.has(&"yellow_potion"), "Story night skip preserves remaining potions.")
	test.expect(flow.resume_game(0, GameFlow.Mode.DAY), "Normal flow can continue after the isolated story-skip test.")

	var day_result := DayResult.new()
	day_result.remaining_health = 80
	day_result.collected_items = {&"herdsmans_loaf_bush": 3}
	test.expect(flow.complete_day(day_result), "Completing daytime enters night.")
	test.expect(flow.current_runtime is NightRuntime, "NightRuntime is active.")
	test.expect(flow.current_runtime.player_data == player, "NightRuntime receives the same PlayerData instance.")
	test.expect(flow.current_runtime.current_night_result != null, "NightRuntime owns one current NightResult.")
	test.expect(flow.current_runtime.alchemy_runtime.night_result == flow.current_runtime.current_night_result, "AlchemyRuntime receives NightRuntime's exact NightResult instance.")
	test.expect(flow.current_runtime.shop_slot.visible, "The night shop is the default visible night scene.")
	test.expect(not flow.current_runtime.alchemy_slot.visible, "Alchemy stays hidden until the player uses its station.")
	var night_player := flow.current_runtime.night_home.get_node("Player") as CharacterBody2D
	var night_entry := flow.current_runtime.night_home.get_node("EntryPoints/default") as Marker2D
	test.expect_equal(night_player.global_position, night_entry.global_position, "Day completion places the player at the night default marker.")
	test.expect_equal(player.inventory[&"herdsmans_loaf_bush"], 3, "Day result is applied before night.")

	var night_result := NightResult.new()
	night_result.earned_money = 20
	test.expect(flow.complete_night(night_result), "Completing night enters the next day.")
	test.expect_equal(flow.current_day, 1, "The day advances from day zero after night.")
	test.expect(flow.current_runtime is DayRuntime, "The next DayRuntime is active.")
	test.expect_equal(player.money, 20, "Night result is applied before the next day.")
	test.expect(flow.resume_game(1, GameFlow.Mode.NIGHT), "A later night can be resumed for the sleep transition.")
	var sleep_result := NightResult.new()
	sleep_result.earned_money = 7
	test.expect(flow.complete_night_to_bedroom(sleep_result), "Sleeping completes night into the next bedroom.")
	test.expect_equal(flow.current_day, 2, "Sleeping advances exactly one day.")
	test.expect(flow.current_runtime is DayRuntime, "Sleeping creates the next DayRuntime.")
	test.expect_equal((flow.current_runtime as DayRuntime).current_level.id, &"bedroom", "Sleeping forces the next day to start in bedroom.")
	test.expect_equal(player.money, 27, "The sleep transition applies its NightResult exactly once.")
	test.expect(flow.debug_set_day(7), "The debug day setter reloads the active runtime.")
	test.expect_equal(flow.current_day, 7, "The debug day setter updates the current day.")
	test.expect(flow.current_runtime is DayRuntime, "Setting the day keeps the active day runtime mode.")
	test.expect_equal((flow.current_runtime as DayRuntime).day, 7, "The rebuilt DayRuntime receives the requested day.")
	test.expect(not flow.debug_set_day(GameFlow.FINAL_DAY + 1), "The debug day setter rejects days outside the supported range.")

	test.expect(flow.resume_game(30, GameFlow.Mode.NIGHT), "A day-30 night can be resumed.")
	test.expect(flow.complete_night_to_bedroom(NightResult.new()), "Day 30 sleep completes.")
	test.expect_equal(flow.current_mode, GameFlow.Mode.ENDING, "Day 30 enters the ending.")
	test.expect(flow.current_runtime == null, "The ending does not create an unused runtime.")

	flow.shutdown()
	flow.free()
	runtime_slot.free()

extends RefCounted


static func run(test: TestSupport) -> void:
	var runtime_slot := Node.new()
	var flow := GameFlow.new()
	var player := PlayerData.new()
	flow.configure(runtime_slot, player)

	test.expect(flow.start_new_game(), "A new game starts in the day runtime.")
	test.expect_equal(flow.current_day, 1, "A new game starts on day one.")
	test.expect(flow.current_runtime is DayRuntime, "DayRuntime is active.")
	test.expect(flow.current_runtime.player_data == player, "DayRuntime receives the shared PlayerData instance.")
	var emitted_day_result := DayResult.new()
	emitted_day_result.remaining_health = 95
	(flow.current_runtime as DayRuntime).finish_day(emitted_day_result)
	test.expect(flow.current_runtime is NightRuntime, "A DayRuntime completion signal can safely transition to night.")
	test.expect_equal(player.health, 95, "Signal-driven daytime completion applies its result.")
	test.expect(flow.resume_game(1, GameFlow.Mode.DAY), "The signal-driven transition can rebuild day mode.")
	test.expect(flow.resume_game(1, GameFlow.Mode.DAY), "Resuming the current mode rebuilds its runtime.")
	test.expect_equal(flow.current_day, 1, "Same-mode resume restores the requested day.")
	test.expect(flow.current_runtime.player_data == player, "A rebuilt runtime still receives shared PlayerData.")

	var day_result := DayResult.new()
	day_result.remaining_health = 80
	day_result.collected_items = {&"herdsmans_loaf_bush": 3}
	test.expect(flow.complete_day(day_result), "Completing daytime enters night.")
	test.expect(flow.current_runtime is NightRuntime, "NightRuntime is active.")
	test.expect(flow.current_runtime.player_data == player, "NightRuntime receives the same PlayerData instance.")
	test.expect(flow.current_runtime.current_night_result != null, "NightRuntime owns one current NightResult.")
	test.expect(flow.current_runtime.alchemy_runtime.night_result == flow.current_runtime.current_night_result, "AlchemyRuntime receives NightRuntime's exact NightResult instance.")
	test.expect_equal(player.inventory[&"herdsmans_loaf_bush"], 3, "Day result is applied before night.")

	var night_result := NightResult.new()
	night_result.earned_money = 20
	test.expect(flow.complete_night(night_result), "Completing night enters the next day.")
	test.expect_equal(flow.current_day, 2, "The day advances after night.")
	test.expect(flow.current_runtime is DayRuntime, "The next DayRuntime is active.")
	test.expect_equal(player.money, 20, "Night result is applied before the next day.")

	test.expect(flow.resume_game(30, GameFlow.Mode.NIGHT), "A day-30 night can be resumed.")
	test.expect(flow.complete_night(NightResult.new()), "Day 30 completes.")
	test.expect_equal(flow.current_mode, GameFlow.Mode.ENDING, "Day 30 enters the ending.")
	test.expect(flow.current_runtime == null, "The ending does not create an unused runtime.")

	flow.shutdown()
	flow.free()
	runtime_slot.free()

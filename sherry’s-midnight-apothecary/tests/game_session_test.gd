extends RefCounted


static func run(test: TestSupport) -> void:
	var session := GameSession.new()
	session.money = 120
	session.inventory = {&"moon_mint": 3}
	session.story_flags = [&"met_sherry"]
	var save_data := session.to_save_data()

	(save_data["inventory"] as Dictionary)[&"moon_mint"] = 99
	test.expect_equal(session.inventory[&"moon_mint"], 3, "Save dictionaries are deep copies.")

	save_data = session.to_save_data()
	var restored := GameSession.from_save_data(save_data)
	test.expect_equal(restored.current_day, 1, "Current day round-trips.")
	test.expect_equal(restored.money, 120, "Money round-trips.")
	test.expect_equal(restored.inventory[&"moon_mint"], 3, "Inventory round-trips.")
	test.expect(restored.story_flags.has(&"met_sherry"), "Typed stable ID arrays round-trip.")

	(restored.inventory as Dictionary)[&"moon_mint"] = 8
	test.expect_equal(session.inventory[&"moon_mint"], 3, "Restored dictionaries do not alias the source session.")


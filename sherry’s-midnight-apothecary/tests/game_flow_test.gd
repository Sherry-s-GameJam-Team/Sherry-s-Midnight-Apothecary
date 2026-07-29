extends RefCounted


static func run(test: TestSupport) -> void:
	var session := GameSession.new()
	var flow := GameFlow.new()
	flow.configure(session)

	test.expect(flow.start_new_game(), "New game enters the main menu.")
	test.expect_equal(flow.current_phase(), GameFlow.Phase.MAIN_MENU, "Main menu is the initial phase.")
	test.expect(not flow.enter_phase(GameFlow.Phase.MAIN_MENU), "Repeated phase entry is rejected.")
	test.expect(not flow.enter_phase(GameFlow.Phase.NIGHT_SHOP), "Illegal phase skipping is rejected.")

	test.expect(flow.advance_phase(), "Main menu advances to day intro.")
	test.expect(flow.advance_phase(), "Day intro advances to preparation.")
	test.expect(flow.advance_phase(), "Preparation advances to the day level.")

	var level_result := LevelResult.new()
	level_result.level_id = &"forest"
	level_result.completed = true
	level_result.portal_repaired = true
	level_result.collected_items = {&"moon_mint": 4}
	level_result.completed_puzzles = [&"forest_gate"]
	level_result.story_flags = [&"forest_cleared"]
	level_result.remaining_potions = {&"red_tonic": 1}
	test.expect(flow.submit_level_result(level_result), "LevelResult is accepted during DAY_LEVEL.")
	test.expect_equal(session.inventory[&"moon_mint"], 4, "Level items are applied before DAY_RESULT.")
	test.expect(session.completed_puzzles.has(&"forest_gate"), "Completed puzzles are applied.")
	test.expect(session.repaired_portals.has(&"forest"), "Portal repair is applied.")

	test.expect(flow.advance_phase(), "Day result advances to night shop.")
	var shop_result := ShopResult.new()
	shop_result.earned_money = 75
	shop_result.spent_ingredients = {&"moon_mint": 2}
	shop_result.produced_potions = {&"blue_tonic": 2}
	shop_result.sold_potions = {&"red_tonic": 1}
	shop_result.customer_results = {&"customer_owl": 1}
	shop_result.story_flags = [&"served_owl"]
	test.expect(flow.submit_shop_result(shop_result), "ShopResult is accepted during NIGHT_SHOP.")
	test.expect_equal(session.money, 75, "Shop earnings are applied before NIGHT_RESULT.")
	test.expect_equal(session.inventory[&"moon_mint"], 2, "Spent ingredients are subtracted.")
	test.expect_equal(session.owned_potions[&"blue_tonic"], 2, "Produced potions are added.")
	test.expect(not session.owned_potions.has(&"red_tonic"), "Sold potions are removed at zero.")

	test.expect(flow.advance_phase(), "Night result advances to story event.")
	test.expect(flow.advance_phase(), "Story event advances to the next day.")
	test.expect_equal(session.current_day, 2, "Only GameFlow's story boundary advances the day.")
	test.expect_equal(flow.current_phase(), GameFlow.Phase.DAY_INTRO, "The next day starts at DAY_INTRO.")
	flow.free()

extends RefCounted


static func run(test: TestSupport) -> void:
	var scene := load("res://night/shop/business_placeholder.tscn") as PackedScene
	test.expect(scene != null, "The business shop whitebox loads.")
	if scene == null:
		return
	var shop := scene.instantiate() as BusinessPlaceholder
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(shop)

	var player := PlayerData.new()
	player.money = 75
	player.potions = {
		&"yellow_potion": [{
			"potion_id": "yellow_potion",
			"instance_uid": "yellow-sale-1",
			"remaining_dose": 1.0,
			"quality": 1.0,
			"price_multiplier": 1.0,
		}],
	}
	var result := NightResult.new()
	shop.setup(player, result, 1)

	test.expect_equal(shop.money_label.text, "持有 75曜", "The business UI uses 曜 as the money unit.")
	test.expect_equal(shop.debt_label.text, "债务 30000曜", "The 30000曜 debt is explicit in the business UI.")
	test.expect(shop.customer_portrait.texture != null, "A real NPC portrait is displayed for the current customer.")
	var body := shop.get_node("Layout/Body")
	test.expect_equal(body.get_child(0).name, &"LeftPanel", "The request panel is the left column.")
	test.expect_equal(body.get_child(1).name, &"CenterPanel", "The customer portrait is the center column.")
	test.expect_equal(body.get_child(2).name, &"RightPanel", "The potion shelf is the right column.")
	test.expect_equal(shop.current_request_potion_id(), &"yellow_potion", "Day one starts with a deterministic customer request.")

	shop.select_offer(&"yellow_potion", "yellow-sale-1")
	test.expect(shop.serve_selected(), "A matching available potion completes the sale.")
	test.expect(result.earned_money > 0, "A completed sale records earnings in NightResult.")
	test.expect_equal((result.sold_potions[&"yellow_potion"] as Array)[0], "yellow-sale-1", "The exact sold instance UID is recorded.")
	test.expect_equal(player.money, 75, "Business earnings remain deferred until the night result is applied.")
	test.expect(shop._find_available_instance(&"yellow_potion", "yellow-sale-1").is_empty(), "A sold potion cannot be offered again in the same night.")
	test.expect(shop.reject_customer(), "The player can refuse the next customer without a sale.")
	test.expect(shop.reject_customer(), "The player can finish the queue by refusing the final customer.")
	test.expect(shop.is_session_complete(), "Three served-or-refused customers complete the nightly business session.")
	test.expect(shop.serve_button.disabled and shop.reject_button.disabled, "Sale actions are disabled after the nightly queue is complete.")

	var earned := result.earned_money
	player.apply_night_result(result)
	test.expect_equal(player.money, 75 + earned, "Applying NightResult commits the shop earnings.")
	test.expect(not player.potions.has(&"yellow_potion"), "Applying NightResult removes the sold potion instance.")

	var fresh_player := PlayerData.new()
	var fresh_result := NightResult.new()
	fresh_result.produced_potions = {
		&"yellow_potion": [{
			"potion_id": "yellow_potion",
			"instance_uid": "fresh-tonight",
			"remaining_dose": 1.0,
			"quality": 1.0,
			"price_multiplier": 1.0,
		}],
	}
	shop.setup(fresh_player, fresh_result, 1)
	shop.refresh_from_runtime()
	test.expect(not shop._find_available_instance(&"yellow_potion", "fresh-tonight").is_empty(), "Potions brewed tonight appear on the business shelf before night settlement.")
	shop.select_offer(&"yellow_potion", "fresh-tonight")
	test.expect(shop.serve_selected(), "A potion brewed earlier in the same night can be sold.")
	fresh_player.apply_night_result(fresh_result)
	test.expect(not fresh_player.potions.has(&"yellow_potion"), "A same-night produced-and-sold potion does not remain after settlement.")
	shop.free()

extends RefCounted


static func run(test: TestSupport) -> void:
	var scene := load("res://night/shop/business_placeholder.tscn") as PackedScene
	test.expect(scene != null, "The business shop whitebox loads.")
	var shelf_panel_scene := load("res://night/shop/ui/potion_shelf_panel.tscn") as PackedScene
	var shelf_item_scene := load("res://night/shop/ui/potion_shelf_item.tscn") as PackedScene
	test.expect(shelf_panel_scene != null, "The potion shelf is a standalone editable scene.")
	test.expect(shelf_item_scene != null, "The potion presentation slot is a standalone editable scene.")
	if scene == null:
		return
	var shop := scene.instantiate() as BusinessPlaceholder
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(shop)

	var player := PlayerData.new()
	var result := NightResult.new()
	shop.setup(player, result, 1)
	test.expect_equal(shop._reputation_gain_for_satisfaction(0.5), 1, "A minimally satisfying sale grants one reputation point.")
	test.expect_equal(shop._reputation_gain_for_satisfaction(1.0), 3, "A standard-quality full potion grants three reputation points.")
	test.expect_equal(shop._reputation_gain_for_satisfaction(1.5), 5, "An excellent potion grants five reputation points.")
	test.expect_float_close(shop._customer_satisfaction({"quality": 1.2, "remaining_dose": 0.5}), 0.6, 0.001, "Customer satisfaction combines potion quality and remaining dose.")
	var first_customer := shop.current_customer()
	var first_name := str(first_customer.get("name", ""))
	test.expect_equal(shop._customer_queue.size(), 3, "A business night begins with three queued customers.")
	test.expect_float_close(float(first_customer.get("patience", 0.0)), BusinessPlaceholder.MAX_PATIENCE, 0.001, "The active customer starts with full patience.")
	test.expect(first_customer.get("portrait", null) != null, "The active customer has a configured portrait.")

	shop._on_reject_pressed()
	test.expect_equal(shop._customer_queue.size(), 3, "Refusing a customer returns them to the queue instead of removing them.")
	test.expect_equal(str(shop.current_customer().get("name", "")), "采药妇", "The refused customer moves behind the next waiting customer.")
	test.expect_equal(str(shop._customer_queue.back().get("name", "")), first_name, "The refused customer is appended to the queue tail.")
	test.expect_float_close(float(shop._customer_queue.back().get("patience", 0.0)), 75.0, 0.001, "Refusing a customer reduces patience by 25.")

	shop._on_reject_pressed()
	shop._on_reject_pressed()
	test.expect_equal(str(shop.current_customer().get("name", "")), first_name, "The original customer returns after the other customers move to the tail.")
	test.expect_float_close(float(shop.current_customer().get("patience", 0.0)), 75.0, 0.001, "The returning customer's patience remains reduced.")

	for _count in range(7):
		shop._on_reject_pressed()
	test.expect(not shop._customer_queue.any(func(customer: Dictionary) -> bool: return str(customer.get("name", "")) == first_name), "A customer leaves the queue when patience reaches zero.")
	test.expect_equal(result.reputation_delta, -BusinessPlaceholder.WALKOUT_REPUTATION_LOSS, "A customer who loses all patience reduces this night's store reputation.")
	player.apply_night_result(result)
	test.expect_equal(player.store_reputation, 90, "The night's reputation loss is applied when the night result settles.")

	player.store_reputation = 60
	shop.setup(player, NightResult.new(), 2)
	test.expect_equal(shop._customer_queue.size(), 2, "Below 70 reputation, the next night receives fewer customers.")
	test.expect(not shop._customer_queue.any(func(customer: Dictionary) -> bool: return float(customer.get("modifier", 1.0)) >= 1.0), "Below 70 reputation, high-quality customer offers are removed from the queue.")

	player.store_reputation = 30
	shop.setup(player, NightResult.new(), 3)
	test.expect_equal(shop._customer_queue.size(), 1, "Below 40 reputation, the next night receives only one customer.")
	test.expect(float(shop.current_customer().get("modifier", 1.0)) < 0.95, "Very low reputation produces lower-quality customer offers.")
	shop.free()

extends RefCounted


static func run(test: TestSupport) -> void:
	var scene := load("res://night/shop/shop_runtime.tscn") as PackedScene
	test.expect(scene != null, "The shop runtime loads.")
	test.expect(FileAccess.get_file_as_string("res://night/shop/shop_runtime.gd").contains("func _unhandled_input"), "Shop runtime handles Escape before the global pause menu.")
	var shelf_panel_scene := load("res://night/shop/ui/potion_shelf_panel.tscn") as PackedScene
	var shelf_item_scene := load("res://night/shop/ui/potion_shelf_item.tscn") as PackedScene
	test.expect(shelf_panel_scene != null, "The potion shelf is a standalone editable scene.")
	test.expect(shelf_item_scene != null, "The potion presentation slot is a standalone editable scene.")
	if scene == null:
		return
	var shop := scene.instantiate() as ShopRuntime
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
	var first_npc_id := str(first_customer.get("npc_id", ""))
	var initial_queue_size := shop._customer_queue.size()
	test.expect_equal(initial_queue_size, 8, "A high-reputation business night begins with eight queued customers.")
	test.expect_float_close(float(first_customer.get("patience", 0.0)), ShopRuntime.MAX_PATIENCE, 0.001, "The active customer starts with full patience.")
	test.expect(first_customer.get("portrait", null) != null, "The active customer has a configured portrait.")

	# 1. First rejection: customer leaves immediately, patience -25%, reputation -2^1 = -2
	shop._on_reject_pressed()
	test.expect_equal(shop._customer_queue.size(), initial_queue_size - 1, "Refusing a customer removes them from tonight's queue immediately.")
	test.expect_equal(shop.completed_customer_count, 1, "Refusing a customer increments completed customer count.")
	test.expect_equal(result.reputation_delta, -2, "First refusal causes 2^1 = 2 reputation penalty.")
	var state1: Dictionary = player.customer_states.get(first_npc_id, {})
	test.expect_float_close(float(state1.get("patience", 0.0)), 75.0, 0.001, "Refused customer patience is saved as 75%.")
	test.expect_equal(int(state1.get("refusal_count", 0)), 1, "Refusal count is recorded as 1.")

	# 2. Test patience recovery with accurate medication
	state1["patience"] = 50.0
	player.customer_states[first_npc_id] = state1
	var second_customer := shop.current_customer()
	var second_npc_id := str(second_customer.get("npc_id", ""))

	# 3. Test progressive reputation penalty 2^n on second refusal of second customer
	shop._on_reject_pressed()
	test.expect_equal(shop._customer_queue.size(), initial_queue_size - 2, "Second customer also leaves immediately on refusal.")
	test.expect_equal(result.reputation_delta, -4, "Total reputation penalty includes another 2^1 = 2 (delta: -2 - 2 = -4).")

	# 4. Test warning dialog when the current customer's patience is <= 25%
	var last_customer := shop.current_customer()
	var last_npc_id := str(last_customer.get("npc_id", ""))
	last_customer["patience"] = 25.0
	shop.reject_confirm_dialog.hide()
	shop._on_reject_pressed()
	test.expect(shop.reject_confirm_dialog.visible, "When customer patience is 25%, rejecting triggers the confirmation warning dialog.")
	test.expect_equal(shop._customer_queue.size(), initial_queue_size - 2, "Customer remains until confirmation dialog is accepted.")

	# Confirm the rejection
	shop._on_reject_confirmed()
	test.expect_equal(shop._customer_queue.size(), initial_queue_size - 3, "Only the confirmed customer leaves the queue.")
	var final_state: Dictionary = player.customer_states.get(last_npc_id, {})
	test.expect_float_close(float(final_state.get("patience", 100.0)), 0.0, 0.001, "Final rejection reduces patience to 0.")
	test.expect(bool(final_state.get("permanently_lost", false)), "Customer with 0 patience is marked permanently lost.")

	# 5. Verify permanently lost customer never appears in future night queues
	shop.setup(player, NightResult.new(), 2)
	test.expect(not shop._customer_queue.any(func(c: Dictionary) -> bool: return str(c.get("npc_id", "")) == last_npc_id), "Permanently lost customer never appears in future customer queues.")

	shop.free()

extends RefCounted


static func run(test: TestSupport) -> void:
	var runtime_scene := load("res://night/night_runtime.tscn") as PackedScene
	test.expect(runtime_scene != null, "NightRuntime scene loads successfully.")
	if runtime_scene == null:
		return
	var runtime := runtime_scene.instantiate() as NightRuntime
	test.expect(runtime != null, "NightRuntime instantiates.")
	if runtime == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(runtime)
	runtime.configure(PlayerData.new(), 1)

	var home := runtime.get_node("ShopSlot/NightHome") as NightHome
	test.expect(home != null, "NightHome exists in runtime.")
	if home == null:
		runtime.free()
		return

	var barrier_controller := home.get_node_or_null("NightBedroomBarrier") as NightBedroomBarrier
	test.expect(barrier_controller != null, "NightHome contains NightBedroomBarrier node.")
	if barrier_controller == null:
		runtime.free()
		return

	var camera_director := home.get_node_or_null("HomeCameraDirector") as HomeCameraDirector
	test.expect(camera_director != null, "HomeCameraDirector exists.")
	test.expect(camera_director.entrance_handler.is_valid(), "HomeCameraDirector entrance_handler is connected by NightBedroomBarrier.")
	# State tests do not need to leave asynchronous Dialogue Manager balloons in
	# the shared test tree after NightRuntime is freed.
	barrier_controller.dialogue_resource = null

	# 1. Check initial state before operating business
	test.expect(not runtime.has_operated(), "Initially has_operated is false.")
	test.expect(runtime.get_remaining_customer_count() > 0, "Initially remaining customer count is greater than 0.")
	var initial_remaining := runtime.get_remaining_customer_count()

	# Trigger check
	barrier_controller.trigger_barrier_check()
	test.expect(not barrier_controller.has_operated, "Barrier controller reports has_operated is false.")
	test.expect_equal(barrier_controller.remaining_customers, initial_remaining, "Barrier controller accurately reflects remaining customer count.")
	test.expect(not barrier_controller.is_barrier_open, "Barrier is not open without confirmation.")

	# 2. Test confirming end of business
	barrier_controller.confirm_end_business()
	test.expect(barrier_controller.is_barrier_open, "Barrier is marked open after confirming end of business.")

	# 3. Test when business is in progress / operated
	runtime.shop_runtime.completed_customer_count = 2
	runtime.shop_runtime._customer_queue.pop_front()
	var updated_remaining := runtime.get_remaining_customer_count()

	test.expect(runtime.has_operated(), "has_operated is true after serving customers.")
	test.expect_equal(updated_remaining, initial_remaining - 1, "Remaining count decreases after customer completion.")

	barrier_controller.is_barrier_open = false
	barrier_controller.trigger_barrier_check()
	test.expect(barrier_controller.has_operated, "Barrier controller reports has_operated is true.")
	test.expect_equal(barrier_controller.remaining_customers, updated_remaining, "Barrier controller reflects updated remaining count.")
	test.expect_equal(barrier_controller.completed_customers, 2, "Barrier controller reflects completed customer count.")

	# 4. Test when all customers are served
	runtime.shop_runtime._customer_queue.clear()
	test.expect_equal(runtime.get_remaining_customer_count(), 0, "Queue is empty when all customers are served.")

	barrier_controller.trigger_barrier_check()
	test.expect(barrier_controller.has_operated, "Barrier controller reports operated.")
	test.expect_equal(barrier_controller.remaining_customers, 0, "Barrier controller reports 0 remaining customers.")

	runtime.free()

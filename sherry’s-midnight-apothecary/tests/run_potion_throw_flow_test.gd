extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("POTION THROW FLOW TEST FAILED: %s" % message)


func _run() -> void:
	var player_data := PlayerData.from_save_data({"potions": {"red_potion": [{
		"instance_uid": "flow-red",
		"remaining_dose": 1.0,
		"quality": 1.0,
		"potency": 1.0,
		"duration": 1.0,
	}]}})
	var runtime: DayRuntime = preload("res://day/day_runtime.tscn").instantiate()
	runtime.configure(player_data, 1)
	root.add_child(runtime)
	for _frame in range(90):
		await physics_frame
	var level := runtime.level_slot.get_child(runtime.level_slot.get_child_count() - 1)
	var player := level.get_node("Player")
	var thrower: PotionThrower = player.get_node("PotionThrower")
	_expect(player.is_on_floor(), "Player reaches the configured Town floor before aiming.")
	_expect(thrower._begin_aim(), "Grounded idle player can begin potion aiming.")
	_expect(is_equal_approx(Engine.time_scale, thrower.throw_tuning.aim_time_scale), "Aiming applies configured bullet time.")
	_expect(player._potion_action_locked, "Aiming locks active movement input.")
	thrower.cancel_aim()
	_expect(is_equal_approx(thrower.inventory_service.get_total_dose(&"red_potion"), 1.0), "Right-click style cancellation does not consume dose.")
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Cancellation restores time scale.")
	_expect(thrower._begin_aim(), "A second aim reservation can start after cancellation.")
	thrower._drag_start_mouse = thrower.get_global_mouse_position()
	thrower._finish_aim()
	_expect(is_equal_approx(thrower.inventory_service.get_total_dose(&"red_potion"), 1.0), "Drag below threshold cancels without consuming dose.")
	_expect(thrower._begin_aim(), "A valid throw can reserve dose after threshold cancellation.")
	thrower._drag_start_mouse = thrower.get_global_mouse_position() - Vector2(-140, 90)
	thrower._finish_aim()
	_expect(thrower._casting, "Valid release enters the cast animation state.")
	_expect(is_equal_approx(thrower.inventory_service.get_total_dose(&"red_potion"), 1.0), "Dose remains reserved until the animation release frame.")
	thrower.on_cast_release()
	_expect(is_equal_approx(thrower.inventory_service.get_total_dose(&"red_potion"), 0.75), "Successful projectile spawn commits configured dose.")
	_expect(thrower._active_projectile != null, "Animation release spawns the SVG potion projectile at AimOrigin.")
	if thrower._active_projectile != null:
		thrower._active_projectile._break(thrower._active_projectile.global_position, Vector2.UP)
	for _frame in range(180):
		await physics_frame
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Projectile break and camera return restore time scale.")
	_expect(not player._potion_action_locked, "Cast completion restores character control.")
	_expect(thrower._begin_aim(), "A later throw can begin after normal camera recovery.")
	thrower._drag_start_mouse = thrower.get_global_mouse_position() - Vector2(-120, 80)
	thrower._finish_aim()
	thrower.on_cast_release()
	_expect(is_equal_approx(thrower.inventory_service.get_total_dose(&"red_potion"), 0.5), "A second successful launch commits one additional dose.")
	_expect(runtime.switch_to_level("forest"), "Scene switching remains available during projectile flight.")
	for _frame in range(8):
		await physics_frame
	_expect(is_equal_approx(Engine.time_scale, 1.0), "Scene switch and forced projectile deletion restore time scale.")
	runtime.queue_free()
	await process_frame
	await process_frame
	PotionSvgRenderer.clear_cache()
	Engine.time_scale = 1.0
	if failures == 0:
		print("Potion aim, cancellation, cast, dose commit and recovery tests passed.")
		quit(0)
	else:
		push_error("%d potion throw flow assertion(s) failed." % failures)
		quit(1)

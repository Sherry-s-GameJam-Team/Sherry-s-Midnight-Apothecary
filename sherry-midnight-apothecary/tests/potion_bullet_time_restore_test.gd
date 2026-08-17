extends SceneTree

const SCENE_PATH := "res://day/levels/forest/crown/forest_crown.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_data := PlayerData.from_save_data({
		"equipped_potion_ids": ["purification_potion", "", "", ""],
		"selected_potion_slot": 0,
		"potions": {
			"purification_potion": [
				{"instance_uid": "bt-1", "remaining_dose": 1.0, "quality": 1.0, "potency": 1.0, "duration": 1.0},
				{"instance_uid": "bt-2", "remaining_dose": 1.0, "quality": 1.0, "potency": 1.0, "duration": 1.0},
			]
		}
	})

	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Unable to load %s" % SCENE_PATH)
		_finish()
		return

	var level := packed.instantiate()
	if level.has_method("set_player_data"):
		level.call("set_player_data", player_data)
	level.set_meta("player_data", player_data)
	root.add_child(level)
	await process_frame
	await process_frame

	var player := level.get_node_or_null("Player")
	if player == null:
		_fail("Player node is null")
		_finish()
		return

	var thrower: PotionThrower = player.get_node_or_null("PotionThrower")
	if thrower == null:
		_fail("PotionThrower node is null")
		_finish()
		return

	thrower.inventory_service = PotionInventoryService.new(player_data)
	thrower.inventory_service.setup(player_data)

	# 1. Test aim bullet time
	if not thrower._begin_aim():
		_fail("Failed to begin aim")

	if not is_equal_approx(Engine.time_scale, thrower.throw_tuning.aim_time_scale):
		_fail("Engine.time_scale should be aim_time_scale (%f), got: %f" % [thrower.throw_tuning.aim_time_scale, Engine.time_scale])

	# 2. Test throw release & flight bullet time
	thrower._drag_start_mouse = thrower.get_global_mouse_position() - Vector2(-100, 50)
	thrower._finish_aim()
	await physics_frame

	var proj: PotionProjectile = thrower._active_projectile
	if proj == null:
		_fail("Active projectile should not be null after throw release")
	else:
		if not is_equal_approx(Engine.time_scale, thrower.throw_tuning.flight_time_scale):
			_fail("Engine.time_scale should be flight_time_scale (%f), got: %f" % [thrower.throw_tuning.flight_time_scale, Engine.time_scale])

		# 3. Simulate projectile breaking / landing
		proj._break(proj.global_position, Vector2.UP)
		await physics_frame
		await physics_frame

		if not is_equal_approx(Engine.time_scale, 1.0):
			_fail("Engine.time_scale should be restored to 1.0 after projectile breaks, got: %f" % Engine.time_scale)

	# 4. Test cancel aim restoring 1.0
	thrower._begin_aim()
	if not is_equal_approx(Engine.time_scale, thrower.throw_tuning.aim_time_scale):
		_fail("Engine.time_scale should be aim_time_scale on second aim")
	thrower.cancel_aim()
	if not is_equal_approx(Engine.time_scale, 1.0):
		_fail("Engine.time_scale should be restored to 1.0 after cancel_aim, got: %f" % Engine.time_scale)

	level.queue_free()
	await process_frame
	_finish()


func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)


func _finish() -> void:
	if failures.is_empty():
		print("POTION_BULLET_TIME_RESTORE_TEST: PASS")
		quit(0)
	else:
		print("POTION_BULLET_TIME_RESTORE_TEST: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)

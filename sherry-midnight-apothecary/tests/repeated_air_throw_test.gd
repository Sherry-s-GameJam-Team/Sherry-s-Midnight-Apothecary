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
				{"instance_uid": "p-1", "remaining_dose": 1.0, "quality": 1.0, "potency": 1.0, "duration": 1.0},
				{"instance_uid": "p-2", "remaining_dose": 1.0, "quality": 1.0, "potency": 1.0, "duration": 1.0},
				{"instance_uid": "p-3", "remaining_dose": 1.0, "quality": 1.0, "potency": 1.0, "duration": 1.0},
				{"instance_uid": "p-4", "remaining_dose": 1.0, "quality": 1.0, "potency": 1.0, "duration": 1.0},
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

	# Put player in airborne state
	player._is_airborne = true
	player._state = "jump_fall"

	# 1. First Air Throw
	if not thrower._begin_aim():
		_fail("First air aim failed")

	thrower._drag_start_mouse = thrower.get_global_mouse_position() - Vector2(-100, 50)
	thrower._finish_aim()
	await physics_frame
	await physics_frame

	# 2. Second Air Throw while still airborne
	if not thrower._begin_aim():
		_fail("Second air aim failed (consecutive mid-air throw blocked!)")

	thrower._drag_start_mouse = thrower.get_global_mouse_position() - Vector2(-100, 50)
	thrower._finish_aim()
	await physics_frame
	await physics_frame

	# 3. Third Air Throw while still airborne
	if not thrower._begin_aim():
		_fail("Third air aim failed")

	thrower._drag_start_mouse = thrower.get_global_mouse_position() - Vector2(-100, 50)
	thrower._finish_aim()
	await physics_frame
	await physics_frame

	level.queue_free()
	await process_frame
	_finish()


func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)


func _finish() -> void:
	if failures.is_empty():
		print("REPEATED_AIR_THROW_TEST: PASS")
		quit(0)
	else:
		print("REPEATED_AIR_THROW_TEST: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)

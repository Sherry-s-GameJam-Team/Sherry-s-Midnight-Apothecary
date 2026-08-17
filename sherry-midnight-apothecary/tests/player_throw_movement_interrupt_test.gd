extends SceneTree

const SCENE_PATH := "res://day/levels/forest/crown/forest_crown.tscn"

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Unable to load %s" % SCENE_PATH)
		_finish()
		return

	var level := packed.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame

	var player := level.get_node_or_null("Player")
	if player == null:
		_fail("Player node is null")
		_finish()
		return

	var thrower := player.get_node_or_null("PotionThrower")
	if thrower == null:
		_fail("PotionThrower node is null")
		_finish()
		return

	# 1. Test aiming availability in various states
	if not player.can_start_potion_aim():
		_fail("Player should be able to start potion aim while idle")

	player._state = "walk"
	if not player.can_start_potion_aim():
		_fail("Player should be able to start potion aim while walking")

	player._state = "jump_fall"
	player._is_airborne = true
	if not player.can_start_potion_aim():
		_fail("Player should be able to start potion aim while airborne")

	# 2. Test play_potion_cast and cast animation interruption by movement
	player._is_airborne = false
	player._state = "idle"
	player.play_potion_cast()

	if player._state != "cast":
		_fail("Player should enter 'cast' state upon play_potion_cast(), got: %s" % player._state)

	# Simulate pressing movement key (direction = 1.0)
	player._interrupt_cast_by_movement(1.0)

	if player._state != "walk" and player._state != "run":
		_fail("Cast animation should be immediately interrupted into walk/run by movement, got: %s" % player._state)
	if player._potion_cast_active:
		_fail("_potion_cast_active should be false after movement interrupt")

	# 3. Test cast animation interrupted by jump
	player.play_potion_cast()
	if player._state != "cast":
		_fail("Player should enter 'cast' state again")

	player._start_jump()
	if player._state != "prejump" and player._state != "jump_takeoff":
		_fail("Cast animation should be interrupted by jump, got: %s" % player._state)

	level.queue_free()
	await process_frame
	_finish()


func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)


func _finish() -> void:
	if failures.is_empty():
		print("PLAYER_THROW_MOVEMENT_INTERRUPT_TEST: PASS")
		quit(0)
	else:
		print("PLAYER_THROW_MOVEMENT_INTERRUPT_TEST: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)

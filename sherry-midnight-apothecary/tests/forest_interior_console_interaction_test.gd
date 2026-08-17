extends SceneTree

const SCENE_PATH := "res://day/levels/forest/interior/forest_interior.tscn"

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Unable to load %s" % SCENE_PATH)
		_finish()
		return
	var level := packed.instantiate() as ForestInteriorLevel
	root.add_child(level)
	await process_frame

	var player: CharacterBody2D = level.player
	var luca: CharacterBody2D = level.luca
	var party: ForestPartyController = level.party

	if player == null or luca == null or party == null:
		_fail("Missing core nodes in level")
		_finish()
		return

	# 1. Test LiftAConsole (Luca)
	var lift_a_console: ForestLucaConsole = level.get_node_or_null("LucaWorldOnly/LiftAConsole") as ForestLucaConsole
	var root_lift_a: AnimatableBody2D = level.get_node_or_null("RealityWorld/RootLiftA") as AnimatableBody2D
	if lift_a_console == null or root_lift_a == null:
		_fail("Missing LiftAConsole or RootLiftA")
	else:
		party.set_active_character(&"luca")
		await process_frame
		luca.global_position = lift_a_console.global_position + Vector2(0, -20)
		luca.velocity = Vector2.ZERO
		for i in range(5):
			await physics_frame
		await process_frame

		if not lift_a_console._operator_inside:
			_fail("Luca at LiftAConsole was not detected by Area2D")
		if not lift_a_console.prompt.visible:
			_fail("LiftAConsole prompt is not visible when Luca is present and active")

		var prev_y := root_lift_a.position.y
		var event := InputEventKey.new()
		event.pressed = true
		event.physical_keycode = KEY_E
		event.keycode = KEY_E
		lift_a_console._unhandled_input(event)
		await process_frame

		for i in range(10):
			await physics_frame
		if root_lift_a.position.y == prev_y and not root_lift_a._is_moving:
			_fail("RootLiftA did not activate upon pressing E at LiftAConsole")

	# 2. Test LiftAConsoleReality (Sherry)
	var lift_a_sherry: ForestLucaConsole = level.get_node_or_null("RealityWorld/LiftAConsoleReality") as ForestLucaConsole
	if lift_a_sherry != null:
		party.set_active_character(&"sherry")
		await process_frame
		player.global_position = lift_a_sherry.global_position + Vector2(0, -20)
		player.velocity = Vector2.ZERO
		for i in range(5):
			await physics_frame
		await process_frame

		if not lift_a_sherry._operator_inside:
			_fail("Sherry at LiftAConsoleReality was not detected by Area2D")
		if not lift_a_sherry.prompt.visible:
			_fail("LiftAConsoleReality prompt is not visible when Sherry is present and active")

	# 3. Test RotateConsole (Luca)
	var rotate_console: ForestLucaConsole = level.get_node_or_null("LucaWorldOnly/RotateConsole") as ForestLucaConsole
	var rotating_root: AnimatableBody2D = level.get_node_or_null("RealityWorld/RotatingRoot") as AnimatableBody2D
	if rotate_console != null and rotating_root != null:
		party.set_active_character(&"luca")
		await process_frame
		luca.global_position = rotate_console.global_position + Vector2(0, -20)
		luca.velocity = Vector2.ZERO
		for i in range(5):
			await physics_frame
		await process_frame

		if not rotate_console._operator_inside:
			_fail("Luca at RotateConsole was not detected")
		var event := InputEventKey.new()
		event.pressed = true
		event.physical_keycode = KEY_E
		event.keycode = KEY_E
		rotate_console._unhandled_input(event)
		await process_frame
		for i in range(10):
			await physics_frame
		if not rotating_root._moving and rotating_root._horizontal != true:
			_fail("RotatingRoot did not activate upon pressing E at RotateConsole")

	# 4. Test SluiceConsole (Luca)
	var sluice_console: ForestLucaConsole = level.get_node_or_null("LucaWorldOnly/SluiceConsole") as ForestLucaConsole
	var sluice_gate: AnimatableBody2D = level.get_node_or_null("RealityWorld/SluiceGate") as AnimatableBody2D
	if sluice_console != null and sluice_gate != null:
		party.set_active_character(&"luca")
		await process_frame
		luca.global_position = sluice_console.global_position + Vector2(0, -20)
		luca.velocity = Vector2.ZERO
		for i in range(5):
			await physics_frame
		await process_frame

		if not sluice_console._operator_inside:
			_fail("Luca at SluiceConsole was not detected")
		var event := InputEventKey.new()
		event.pressed = true
		event.physical_keycode = KEY_E
		event.keycode = KEY_E
		sluice_console._unhandled_input(event)
		await process_frame
		for i in range(10):
			await physics_frame
		if not sluice_gate._open and not sluice_gate._moving:
			_fail("SluiceGate did not open upon pressing E at SluiceConsole")

	# 5. Test SprayDevice (Luca)
	var spray_device: ForestSprayDevice = level.get_node_or_null("LucaWorldOnly/SprayDevice") as ForestSprayDevice
	if spray_device != null:
		party.set_active_character(&"luca")
		await process_frame
		luca.global_position = spray_device.global_position + Vector2(0, -20)
		luca.velocity = Vector2.ZERO
		for i in range(5):
			await physics_frame
		await process_frame

		if not spray_device._luca_inside:
			_fail("Luca at SprayDevice was not detected")
		if not spray_device.prompt.visible:
			_fail("SprayDevice prompt not visible")
		var event := InputEventKey.new()
		event.pressed = true
		event.physical_keycode = KEY_E
		event.keycode = KEY_E
		spray_device._unhandled_input(event)
		await process_frame
		if not spray_device._controlling:
			_fail("SprayDevice did not start control mode on pressing E")

	# 6. Test LiftBConsole (Luca)
	var lift_b_console: ForestLucaConsole = level.get_node_or_null("LucaWorldOnly/LiftBConsole") as ForestLucaConsole
	var root_lift_b: AnimatableBody2D = level.get_node_or_null("RealityWorld/RootLiftB") as AnimatableBody2D
	if lift_b_console != null and root_lift_b != null:
		party.set_active_character(&"luca")
		await process_frame
		luca.global_position = lift_b_console.global_position + Vector2(0, -20)
		luca.velocity = Vector2.ZERO
		for i in range(5):
			await physics_frame
		await process_frame

		if not lift_b_console._operator_inside:
			_fail("Luca at LiftBConsole was not detected")
		var prev_y := root_lift_b.position.y
		var event := InputEventKey.new()
		event.pressed = true
		event.physical_keycode = KEY_E
		event.keycode = KEY_E
		lift_b_console._unhandled_input(event)
		await process_frame
		for i in range(10):
			await physics_frame
		if root_lift_b.position.y == prev_y and not root_lift_b._is_moving:
			_fail("RootLiftB did not activate upon pressing E at LiftBConsole")

	level.queue_free()
	await process_frame
	_finish()

func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)

func _finish() -> void:
	if failures.is_empty():
		print("FOREST_INTERIOR_CONSOLE_INTERACTION_TEST: PASS")
		quit(0)
	else:
		print("FOREST_INTERIOR_CONSOLE_INTERACTION_TEST: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)

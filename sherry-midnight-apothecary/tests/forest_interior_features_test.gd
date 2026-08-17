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
	await process_frame

	var player: Node2D = level.player
	var luca: Node2D = level.luca
	var party: ForestPartyController = level.party as ForestPartyController
	var camera: Camera2D = party.camera
	var spray: ForestSprayDevice = level.get_node_or_null("LucaWorldOnly/SprayDevice") as ForestSprayDevice
	var mud_a: ForestInteriorCorruptedMud = level.get_node_or_null("RealityWorld/SprayMudA") as ForestInteriorCorruptedMud
	var mud_b: ForestInteriorCorruptedMud = level.get_node_or_null("RealityWorld/SprayMudB") as ForestInteriorCorruptedMud

	if party == null or camera == null or spray == null or mud_a == null or mud_b == null:
		_fail("Missing essential nodes in level")
		_finish()
		return

	# 1. Test Party Controller switching behavior
	party.set_active_character(&"luca")
	if party.active_character != &"luca":
		_fail("Failed to set active character to luca")
	if camera.get_parent() != luca:
		_fail("Camera was not reparented to Luca when switching to Luca")

	party.enable_switching(false)
	if party.active_character != &"luca":
		_fail("enable_switching(false) incorrectly reset active character away from Luca!")
	if camera.get_parent() != luca:
		_fail("Camera was moved away from Luca when party switching was disabled")
	party.enable_switching(true)

	# 2. Test SprayDevice interaction, camera transition, and W/S aim
	spray.position = luca.position
	spray._luca_inside = true
	spray._begin_control()
	await process_frame

	if not spray._controlling:
		_fail("Spray device did not enter controlling state")
	if camera.get_parent() != spray.camera_focus:
		_fail("Camera was not focused on SprayDevice CameraFocus! Parent is: %s" % str(camera.get_parent()))
	if party.switching_enabled:
		_fail("Party switching should be disabled while controlling spray")

	# Test Aim pitch with W/S
	var initial_rot := spray.pivot.rotation_degrees
	# Simulate pressing ui_up
	Input.action_press("ui_up")
	spray._update_aim(0.1)
	Input.action_release("ui_up")
	if spray.pivot.rotation_degrees >= initial_rot:
		_fail("Pressing Up/W did not decrease rotation degrees (aim up). Current: %f" % spray.pivot.rotation_degrees)

	# Simulate pressing ui_down
	Input.action_press("ui_down")
	spray._update_aim(0.2)
	Input.action_release("ui_down")
	if spray.pivot.rotation_degrees <= initial_rot - 1.0:
		_fail("Pressing Down/S did not increase rotation degrees (aim down). Current: %f" % spray.pivot.rotation_degrees)

	# Test water spray range reaches distance of SprayMudB (~1040px)
	if spray.range < 1100.0:
		_fail("Spray range (%f) is too short to reach SprayMudB (~1040px)" % spray.range)

	# End control
	spray._end_control()
	await process_frame
	if spray._controlling:
		_fail("Spray device failed to end controlling state")
	if camera.get_parent() != luca:
		_fail("Camera did not return to Luca after exiting spray control! Parent is: %s" % str(camera.get_parent()))
	if not party.switching_enabled:
		_fail("Party switching was not re-enabled after exiting spray control")

	# 3. Test Mud Cleansing and Collision Removal
	if mud_a.collision_layer == 0:
		_fail("MudA collision_layer should initially be active")
	mud_a.receive_water_jet(1.0)
	await process_frame
	if mud_a.collision_layer != 0 or mud_a.collision_mask != 0:
		_fail("MudA collision_layer/mask was not cleared to 0 upon purification")
	if not mud_a.collision.disabled:
		_fail("MudA CollisionShape2D was not disabled upon purification")

	# Test potion purification on MudB
	if mud_b.collision_layer == 0:
		_fail("MudB collision_layer should initially be active")
	mud_b.apply_potion_effect(&"purify", {})
	await process_frame
	if mud_b.collision_layer != 0 or mud_b.collision_mask != 0:
		_fail("MudB collision_layer/mask was not cleared to 0 after potion purify")
	if not mud_b.collision.disabled:
		_fail("MudB CollisionShape2D was not disabled after potion purify")

	# 4. Test Background Parallax Setup
	var bg_corrupt: Parallax2D = level.get_node_or_null("Background/CorruptedBackground") as Parallax2D
	var bg_normal: Parallax2D = level.get_node_or_null("Background/NormalBackground") as Parallax2D
	var blood_stream: Parallax2D = level.get_node_or_null("Background/CentralStream/BloodStream") as Parallax2D
	var clear_stream: Parallax2D = level.get_node_or_null("Background/CentralStream/ClearStream") as Parallax2D

	if bg_corrupt == null or bg_normal == null or blood_stream == null or clear_stream == null:
		_fail("Background parallax nodes are missing or not Parallax2D")
	else:
		if bg_corrupt.repeat_size.y <= 0.0 or bg_corrupt.repeat_times < 3:
			_fail("CorruptedBackground vertical repeat is not properly configured for full camera bounds")
		if blood_stream.repeat_size.y <= 0.0 or blood_stream.repeat_times < 3:
			_fail("BloodStream vertical repeat is not properly configured for full camera bounds")

	level.queue_free()
	await process_frame
	_finish()

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("FOREST_INTERIOR_FEATURES_TEST: PASS")
		quit(0)
	else:
		print("FOREST_INTERIOR_FEATURES_TEST: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)

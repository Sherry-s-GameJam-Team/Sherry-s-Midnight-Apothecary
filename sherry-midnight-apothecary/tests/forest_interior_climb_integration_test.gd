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

	var player := level.player
	var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D
	var lift_a: ForestRootLift = level.get_node_or_null("RealityWorld/RootLiftA") as ForestRootLift
	var lift_b: ForestRootLift = level.get_node_or_null("RealityWorld/RootLiftB") as ForestRootLift
	var rotating_root: ForestRotatingRoot = level.get_node_or_null("RealityWorld/RotatingRoot") as ForestRotatingRoot
	var sluice_gate: ForestSluiceGate = level.get_node_or_null("RealityWorld/SluiceGate") as ForestSluiceGate
	var final_gate: ForestSluiceGate = level.get_node_or_null("RealityWorld/FinalGate") as ForestSluiceGate
	var direct_lift: ForestDirectLift = level.get_node_or_null("RealityWorld/UpperControlRoom/DirectLift") as ForestDirectLift
	var exit_to_crown: Area2D = level.get_node_or_null("ExitToCrown") as Area2D

	if player == null or camera == null or lift_a == null or lift_b == null or rotating_root == null or sluice_gate == null or final_gate == null or direct_lift == null or exit_to_crown == null:
		_fail("Essential tower climbing nodes are missing")
		_finish()
		return

	# 1. Test Spawning
	if not level.is_inside_tree():
		_fail("Level failed to enter scene tree")

	# 2. Stage 1: RootLiftA operation
	var initial_lift_a_y := lift_a.position.y
	level.activate_console(&"root_lift_a")
	lift_a.set_high(true, true) # Test instant/target
	if lift_a.position.y >= initial_lift_a_y:
		_fail("RootLiftA did not ascend when toggled high (initial: %f, after: %f)" % [initial_lift_a_y, lift_a.position.y])

	# 3. Stage 2: RotatingRoot operation
	if rotating_root.rotation_degrees != 90.0:
		_fail("RotatingRoot should initially be vertical (90 deg)")
	level.activate_console(&"rotate_beam")
	rotating_root.set_horizontal(true)
	if rotating_root.rotation_degrees != 0.0:
		_fail("RotatingRoot did not rotate to horizontal bridge (0 deg)")

	# 4. Stage 3: Mud Potion and Jet Purify
	var mud_shortcut: ForestInteriorCorruptedMud = level.get_node_or_null("RealityWorld/MudShortcut") as ForestInteriorCorruptedMud
	if mud_shortcut != null:
		mud_shortcut.apply_potion_effect(&"purify")
		await process_frame
		if mud_shortcut.collision_layer != 0:
			_fail("MudShortcut was not cleansed by purify potion")

	# 5. Stage 4: SluiceGate & RootLiftB operation
	var sluice_closed_y := sluice_gate.position.y
	level.activate_console(&"sluice")
	sluice_gate.open_gate(true)
	if sluice_gate.position.y >= sluice_closed_y:
		_fail("SluiceGate did not open upwards")

	var lift_b_low_y := lift_b.position.y
	level.activate_console(&"root_lift_b")
	lift_b.set_high(true, true)
	if lift_b.position.y >= lift_b_low_y:
		_fail("RootLiftB did not ascend when toggled high")

	# 6. Stage 5: Power nodes & DirectLift unlock
	level.activate_console(&"lift_root")
	level.activate_console(&"lift_water")
	if direct_lift._unlocked:
		_fail("DirectLift should not unlock before all 3 power nodes are active")
	level.activate_console(&"lift_crown")
	if not direct_lift._unlocked:
		_fail("DirectLift did not unlock after all 3 power nodes were activated")

	# Final Gate opening
	var final_gate_closed_y := final_gate.position.y
	level.activate_console(&"final_gate")
	final_gate.open_gate(true)
	if final_gate.position.y >= final_gate_closed_y:
		_fail("FinalGate did not open upwards")

	# 7. Summit Crown Exit Trigger
	player.global_position = exit_to_crown.global_position
	exit_to_crown._on_body_entered(player)
	if not exit_to_crown._player_inside:
		_fail("Player entering ExitToCrown did not set _player_inside")
	
	# Simulate pressing E on ExitToCrown
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_E
	exit_to_crown._unhandled_input(event)
	await process_frame
	if not level._get_flag(ForestInteriorLevel.COMPLETED_FLAG):
		_fail("Triggering ExitToCrown should set forest_interior_completed persistent flag")

	level.queue_free()
	await process_frame
	_finish()

func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)

func _finish() -> void:
	if failures.is_empty():
		print("FOREST_INTERIOR_CLIMB_INTEGRATION_TEST: PASS")
		quit(0)
	else:
		print("FOREST_INTERIOR_CLIMB_INTEGRATION_TEST: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)


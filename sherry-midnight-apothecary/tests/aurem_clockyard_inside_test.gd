extends RefCounted


static func run(test: TestSupport) -> void:
	var packed := load("res://day/levels/Aurem Clockyard/inside.tscn") as PackedScene
	test.expect(packed != null, "Inside clocktower scene can be loaded.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	test.expect(level != null, "Inside clocktower scene instantiates.")
	if level == null:
		return

	# Test Player
	var player: CharacterBody2D = level.get_node_or_null("Player") as CharacterBody2D
	test.expect(player != null, "Inside contains Player CharacterBody2D.")
	if player != null:
		test.expect(player.has_node("SherryCollision"), "Player has SherryCollision.")
		test.expect(player.has_node("SherryPresentation"), "Player has SherryPresentation.")
		test.expect(player.has_node("PotionThrower"), "Player has PotionThrower.")
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		test.expect(camera != null, "Player has Camera2D.")
		if camera != null:
			test.expect(camera.position_smoothing_enabled, "Camera has smoothing enabled.")
			test.expect(camera.limit_top <= -4000, "Camera top limit covers tower height.")

	# Test Audio Synthesizer
	var audio := level.get_node_or_null("ClocktowerAudio")
	test.expect(audio != null, "ClocktowerAudio node exists.")

	# Test Entry points
	var entry_points := level.get_node_or_null("EntryPoints")
	test.expect(entry_points != null, "EntryPoints node exists.")
	if entry_points != null:
		test.expect(entry_points.has_node("default"), "default entry exists.")
		test.expect(entry_points.has_node("floor2"), "floor2 entry exists.")
		test.expect(entry_points.has_node("floor3"), "floor3 entry exists.")
		test.expect(entry_points.has_node("floor4"), "floor4 entry exists.")
		test.expect(entry_points.has_node("top"), "top entry exists.")

	# Test Floor 1: Clockwork & Winch Chamber
	var floor1 := level.get_node_or_null("World/Floor1_SpringChamber")
	test.expect(floor1 != null, "Floor 1 Clockwork Chamber exists.")
	var lift1 := level.get_node_or_null("World/Floor1_SpringChamber/WinchLifts/WinchLift1")
	var lift2 := level.get_node_or_null("World/Floor1_SpringChamber/WinchLifts/WinchLift2_Crane")
	test.expect(lift1 != null and lift2 != null, "Both Winch Lifts 1 and 2 exist.")
	if lift1 != null:
		lift1.call("toggle_lift")
		test.expect(lift1.has_method("toggle_lift"), "Winch lift has toggle_lift method.")

	var plat_stone := level.get_node_or_null("World/Floor1_SpringChamber/Platform1_LowStone")
	var plat_chain := level.get_node_or_null("World/Floor1_SpringChamber/Platform2_Chain")
	var plat_ladder := level.get_node_or_null("World/Floor1_SpringChamber/Platform4_LadderGantry")
	test.expect(plat_stone != null and plat_chain != null and plat_ladder != null, "Floor 1 jumping platforms are configured.")

	var secret_plat := level.get_node_or_null("World/Floor1_SpringChamber/HangingPlatform_Secret")
	var floor1_lever := level.get_node_or_null("World/Floor1_SpringChamber/Floor1Lever")
	test.expect(secret_plat != null and floor1_lever != null, "Floor 1 secret hanging platform and lever exist.")
	if floor1_lever != null and secret_plat != null:
		floor1_lever.call("pull_lever")
		test.expect_equal(secret_plat.get("_target_pos"), Vector2(-97, -416), "Hanging platform moves to (-97, -416) on lever pull.")

	var calib_node_1 := level.get_node_or_null("World/Floor1_SpringChamber/CalibrationNode1")
	test.expect(calib_node_1 != null, "Calibration Node 1 exists.")
	if calib_node_1 != null:
		test.expect_equal(calib_node_1.get("node_id"), 1, "Node 1 id is 1.")
		calib_node_1.call("repair_node")
		test.expect(bool(calib_node_1.get("is_fixed")), "Calibration Node 1 can be repaired.")

	# Test Floor 2: Gear Well
	var floor2 := level.get_node_or_null("World/Floor2_GearWell")
	test.expect(floor2 != null, "Floor 2 Gear Well exists.")
	var lever := level.get_node_or_null("World/Floor2_GearWell/CalibrationLever")
	test.expect(lever != null, "Calibration Lever exists.")
	if lever != null:
		lever.call("pull_lever")
		test.expect(bool(lever.get("_is_active")), "Lever activates synchronization.")
	var calib_node_2 := level.get_node_or_null("World/Floor2_GearWell/CalibrationNode2")
	test.expect(calib_node_2 != null, "Calibration Node 2 exists.")
	if calib_node_2 != null:
		calib_node_2.call("repair_node")
		test.expect(bool(calib_node_2.get("is_fixed")), "Calibration Node 2 can be repaired.")

	# Test Floor 3: Pendulum Hall
	var floor3 := level.get_node_or_null("World/Floor3_PendulumHall")
	test.expect(floor3 != null, "Floor 3 Pendulum Hall exists.")
	var pendulum := level.get_node_or_null("World/Floor3_PendulumHall/SwingingPendulum")
	test.expect(pendulum != null, "Swinging Pendulum exists.")
	var calib_node_3 := level.get_node_or_null("World/Floor3_PendulumHall/CalibrationNode3")
	test.expect(calib_node_3 != null, "Calibration Node 3 exists.")
	if calib_node_3 != null:
		calib_node_3.call("repair_node")
		test.expect(bool(calib_node_3.get("is_fixed")), "Calibration Node 3 can be repaired.")

	# Test Floor 4: Clock Hands Floor
	var floor4 := level.get_node_or_null("World/Floor4_ClockHands")
	test.expect(floor4 != null, "Floor 4 Clock Hands Floor exists.")
	if floor4 != null:
		floor4.call("advance_minute_hand", 2)
		test.expect_equal(floor4.get("current_minute_hour"), 3, "Minute hand can be stepped to target III.")

	# Test Tower Top
	var tower_top := level.get_node_or_null("World/TowerTop")
	test.expect(tower_top != null, "Tower Top Synchronizer exists.")
	if tower_top != null:
		tower_top.call("receive_potion_hit", {"potion_id": "blue_potion"})
		test.expect(bool(tower_top.get("is_synchronized")), "Tower Top synchronizes upon ring alignment.")

	# Test Portals
	var entrance_portal := level.get_node_or_null("World/Portals/EntrancePortal")
	var exit_portal := level.get_node_or_null("World/TowerTop/ExitPortal")
	test.expect(entrance_portal != null and exit_portal != null, "Entrance and Exit portals are deployed.")

	level.free()

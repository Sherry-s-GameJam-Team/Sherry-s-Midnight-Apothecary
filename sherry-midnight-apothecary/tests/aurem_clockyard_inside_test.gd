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
	if secret_plat != null:
		test.expect(secret_plat.get("target_position") != Vector2.ZERO, "Hanging platform defines target position.")

	var calib_node_1 := level.get_node_or_null("World/Floor1_SpringChamber/CalibrationNode1")
	test.expect(calib_node_1 != null, "Calibration Node 1 exists.")
	if calib_node_1 != null and secret_plat != null:
		test.expect_equal(calib_node_1.get("node_id"), 1, "Node 1 id is 1.")
		calib_node_1.call("repair_node")
		test.expect(bool(calib_node_1.get("is_fixed")), "Calibration Node 1 can be repaired.")
		test.expect(bool(secret_plat.get("is_activated")), "Calibration Node 1 activation triggers hanging platform movement.")

	# Test Floor 2: Gear Well (Chaotic Hazard Gears)
	var floor2 := level.get_node_or_null("World/Floor2_GearWell")
	test.expect(floor2 != null, "Floor 2 Gear Well exists.")
	var gear1 := level.get_node_or_null("World/Floor2_GearWell/ChaoticGear1")
	var gear2 := level.get_node_or_null("World/Floor2_GearWell/ChaoticGear2")
	var gear3 := level.get_node_or_null("World/Floor2_GearWell/ChaoticGear3")
	var gear4 := level.get_node_or_null("World/Floor2_GearWell/ChaoticGear4")
	test.expect(gear1 != null and gear2 != null and gear3 != null and gear4 != null, "All 4 Chaotic Hazard Gears exist on Floor 2.")

	if gear1 != null:
		var hitbox: Area2D = gear1.get_node_or_null("Hitbox") as Area2D
		test.expect(hitbox != null and hitbox.has_node("CollisionShape2D"), "ChaoticGear1 has Hitbox Area2D with CollisionShape2D.")
		test.expect(gear1.get("damage") > 0, "ChaoticGear1 has positive hazard damage.")
		gear1.call("receive_potion_hit", {"potion_id": "blue_ice_potion"})
		test.expect(bool(gear1.get("_is_frozen")), "Ice potion freezes chaotic gear into static platform.")

	var lever := level.get_node_or_null("World/Floor2_GearWell/CalibrationLever")
	test.expect(lever != null, "Calibration Lever exists.")
	if lever != null:
		lever.call("pull_lever")
		test.expect(bool(lever.get("_is_active")), "Lever activates gear slowdown window.")

	var calib_node_2 := level.get_node_or_null("World/Floor2_GearWell/CalibrationNode2")
	test.expect(calib_node_2 != null, "Calibration Node 2 exists.")
	if calib_node_2 != null and gear1 != null:
		calib_node_2.call("repair_node")
		test.expect(bool(calib_node_2.get("is_fixed")), "Calibration Node 2 can be repaired.")
		test.expect(bool(gear1.get("is_stabilized")), "Calibration Node 2 repairs and permanently stabilizes chaotic gears.")

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

	var clockbird := level.get_node_or_null("World/Floor3_PendulumHall/ClockbirdEnemy")
	test.expect(clockbird != null, "Clockbird Enemy exists in Floor 3.")
	if clockbird != null:
		var frames: Array = clockbird.get("_frames")
		test.expect(frames.size() == 24, "Clockbird loaded all 24 animation frames from res://day/levels/Aurem Clockyard/src/frames/.")
		clockbird.call("receive_potion_hit", {"potion_id": "blue_ice_potion"})
		test.expect_equal(clockbird.get("_state"), 5, "Clockbird transitions to FROZEN state upon ice potion hit.")

	# Test Floor 3: Moving Platforms (150px spacing)
	var mplat1 := level.get_node_or_null("World/Floor3_PendulumHall/MovingPlat1")
	var mplat2 := level.get_node_or_null("World/Floor3_PendulumHall/MovingPlat2")
	var mplat3 := level.get_node_or_null("World/Floor3_PendulumHall/MovingPlat3")
	var mplat4 := level.get_node_or_null("World/Floor3_PendulumHall/MovingPlat4")
	var mplat5 := level.get_node_or_null("World/Floor3_PendulumHall/MovingPlat5")
	test.expect(mplat1 != null and mplat2 != null and mplat3 != null and mplat4 != null and mplat5 != null, "All 5 Floor 3 moving platforms exist.")
	if mplat1 != null and mplat2 != null and mplat3 != null and mplat4 != null and mplat5 != null:
		test.expect_equal(roundi(mplat1.position.y - mplat2.position.y), 150, "Vertical spacing between Plat1 and Plat2 is 150px.")
		test.expect_equal(roundi(mplat2.position.y - mplat3.position.y), 150, "Vertical spacing between Plat2 and Plat3 is 150px.")
		test.expect_equal(roundi(mplat3.position.y - mplat4.position.y), 150, "Vertical spacing between Plat3 and Plat4 is 150px.")
		test.expect_equal(roundi(mplat4.position.y - mplat5.position.y), 150, "Vertical spacing between Plat4 and Plat5 is 150px.")
		mplat1.call("receive_potion_hit", {"potion_id": "blue_ice_potion"})
		test.expect(bool(mplat1.get("_is_frozen")), "Floor 3 moving platform can be frozen by ice potion.")

	# Test Floor 4: Clock Hands Floor
	var floor4 := level.get_node_or_null("World/Floor4_ClockHands")
	test.expect(floor4 != null, "Floor 4 Clock Hands Floor exists.")
	if floor4 != null:
		var hour_crank := floor4.get_node_or_null("HourCrankArea")
		var min_crank := floor4.get_node_or_null("HandCrankArea")
		test.expect(hour_crank != null and min_crank != null, "Dual cranks (Hour and Minute) exist in Floor 4.")

		# Reset starting position: Minute = 1, Hour = 12
		floor4.set("current_minute_hour", 1)
		floor4.set("current_hour_hour", 12)
		floor4.set("_minute_step_counter", 0)

		# Rule 1: Minute turns 3 times -> hour turns an extra 1 time
		floor4.call("turn_minute_hand", 1)
		test.expect_equal(floor4.get("current_minute_hour"), 2, "Minute hand turns 1 step to II.")
		test.expect_equal(floor4.get("current_hour_hour"), 12, "Hour hand unchanged after 1 minute step.")
		floor4.call("turn_minute_hand", 2)
		test.expect_equal(floor4.get("current_minute_hour"), 4, "Minute hand reached IV after 3 total steps.")
		test.expect_equal(floor4.get("current_hour_hour"), 1, "Hour hand advanced +1 to I after 3 minute turns.")

		# Rule 2: Hour turns 1 time -> minute turns an extra 9 times
		floor4.call("turn_hour_hand", 1)
		test.expect_equal(floor4.get("current_hour_hour"), 2, "Hour hand advanced to II.")
		test.expect_equal(floor4.get("current_minute_hour"), 1, "Minute hand advanced +9 from IV to I.")

	# Test Floor 5 & Tower Elevator
	var floor5: Node = level.get_node_or_null("World/floor 5")
	if floor5 == null:
		floor5 = level.get_node_or_null("World/TowerTop")
	test.expect(floor5 != null, "Floor 5 (Tower Synchronizer) exists.")
	if floor5 != null:
		# Test Single Console & Hit logic:
		floor5.set("_outer_angle", 0.0)
		floor5.set("_middle_angle", 180.0)
		floor5.set("_inner_angle", 270.0)
		floor5.call("attempt_lock_at_12")
		test.expect(bool(floor5.get("_outer_locked")), "Outer ring locked on 12 o'clock hit.")
		test.expect(not bool(floor5.get("_middle_locked")), "Middle ring untouched when not at 12 o'clock.")

		# Test Miss-reset logic:
		floor5.set("_middle_angle", 180.0)
		floor5.set("_inner_angle", 270.0)
		floor5.call("attempt_lock_at_12")
		test.expect(not bool(floor5.get("_outer_locked")), "All rings reset/unlocked upon miss.")

		# Test Potion Shortcut:
		floor5.call("receive_potion_hit", {"potion_id": "blue_potion"})
		test.expect(bool(floor5.get("is_synchronized")), "Floor 5 synchronizes upon ring alignment.")

		# Test Elevator activation on sync:
		var elevator: ClocktowerElevator = floor5.get_node_or_null("TowerElevator") as ClocktowerElevator
		test.expect(elevator != null and elevator.is_unlocked and elevator.visible, "Floor 5 elevator unlocks and becomes visible upon grand synchronization.")
		if elevator != null:
			test.expect(elevator.target_position.y <= -2070.0, "Elevator target_position aligns level with Floor 6.")

		# Test Elevator hides when boss battle begins:
		level.call("_on_helion_boss_started")
		if elevator != null:
			test.expect(not elevator.visible, "Floor 5 elevator is hidden during Boss battle.")

	# Test Floor 6 Pinnacle & Portals
	var floor6: Node = level.get_node_or_null("World/Top")
	test.expect(floor6 != null, "Floor 6 (Top Pinnacle) exists.")
	var arena := level.get_node_or_null("World/Top/HelionBossArena")
	if arena != null:
		var sector6_col := arena.get_node_or_null("ClockFloor/Sector06/CollisionShape2D") as CollisionShape2D
		test.expect(sector6_col != null and sector6_col.one_way_collision, "ClockFloor sectors have one_way_collision enabled for elevator passage.")

	var entrance_portal := level.get_node_or_null("World/Portals/EntrancePortal")
	var exit_portal_top := level.get_node_or_null("World/Top/ExitPortal")
	test.expect(entrance_portal != null and exit_portal_top != null, "Entrance and Floor 6 Exit portals are deployed.")

	var top_hint := level.get_node_or_null("GlobalUI/TopHintUI")
	test.expect(top_hint != null, "TopHintUI is instantiated under GlobalUI in inside scene.")
	if top_hint != null and calib_node_1 != null:
		calib_node_1.call("_on_body_entered", player)
		test.expect(top_hint.get("_current") != null, "Entering calibration node triggers interaction hint.")
		calib_node_1.call("_on_body_exited", player)

	level.free()

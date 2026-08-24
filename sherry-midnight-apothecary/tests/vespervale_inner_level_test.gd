extends RefCounted

const INNER_SCRIPT := preload("res://day/levels/Vespervale/inner.gd")


static func run(test: TestSupport) -> void:
	var level_data := load("res://day/levels/Vespervale/vespervale_inner_level.tres") as LevelData
	test.expect(level_data != null, "Vespervale Inner LevelData resource can be loaded.")
	if level_data != null:
		test.expect_equal(level_data.id, &"vespervale_inner", "LevelData id is vespervale_inner.")
		test.expect(level_data.content_scene != null, "LevelData content_scene is assigned.")
		test.expect_equal(level_data.default_entry_id, &"default", "Default entry id is default.")
		test.expect(level_data.display_name.length() > 0, "Display name is configured.")
		test.expect(level_data.disaster_name.length() > 0, "Disaster name is configured.")

	var packed := load("res://day/levels/Vespervale/inner.tscn") as PackedScene
	test.expect(packed != null, "Vespervale Inner scene can be loaded.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	test.expect(level != null, "Vespervale Inner scene instantiates.")
	if level == null:
		return

	if level.has_method("_ready"):
		level.call("_ready")

	test.expect(level is DayLevelEnvironment, "Inner root inherits from DayLevelEnvironment.")
	test.expect(level is VespervaleInnerLevel, "Inner root is VespervaleInnerLevel.")
	var inner_level := level as VespervaleInnerLevel
	test.expect(inner_level.entry_dialogue != null, "Inner has its from-garden entry dialogue resource.")
	if inner_level.entry_dialogue != null:
		test.expect_equal(inner_level.entry_dialogue.resource_path, "res://day/levels/Vespervale/vespervale_inner_entry.dialogue", "Inner uses the authored hospital entry dialogue.")
	test.expect(VespervaleInnerLevel.should_play_entry_dialogue(&"from_garden", null), "Entering through ChurchPortal offers the hospital dialogue.")
	test.expect(not VespervaleInnerLevel.should_play_entry_dialogue(&"default", null), "Other entry points do not play the ChurchPortal dialogue.")
	var completed_entry_data := PlayerData.new()
	completed_entry_data.set_event_flag(VespervaleInnerLevel.ENTRY_DIALOGUE_COMPLETE_FLAG)
	test.expect(not VespervaleInnerLevel.should_play_entry_dialogue(&"from_garden", completed_entry_data), "The hospital entry dialogue does not repeat after completion.")

	var entry_dialogue_source := FileAccess.get_file_as_string("res://day/levels/Vespervale/vespervale_inner_entry.dialogue")
	test.expect(entry_dialogue_source.contains("卢卡？你听得到吗？"), "Entry dialogue begins with Sherry calling Luca.")
	test.expect(entry_dialogue_source.contains("一楼和二楼仍然上下对应"), "Entry dialogue explains the separated hospital floors.")
	test.expect(entry_dialogue_source.contains("病床之间的帘子可以藏身"), "Entry dialogue teaches Luca's curtain hiding rule.")
	test.expect(entry_dialogue_source.contains("这里的问题恐怕不是门锁，而是空间本身"), "Entry dialogue ends with the spatial mystery objective.")
	test.expect(entry_dialogue_source.contains("# [远处传来提灯轻轻碰撞的声音。]"), "The lantern cue remains a stage direction instead of spoken text.")

	var player: CharacterBody2D = level.get_node_or_null("Player") as CharacterBody2D
	test.expect(player != null, "Vespervale Inner contains Player (Sherry).")
	if player != null:
		test.expect(player.has_node("SherryCollision"), "Player has SherryCollision.")
		test.expect(player.has_node("SherryPresentation"), "Player has SherryPresentation.")
		test.expect(player.has_node("PotionThrower"), "Player has PotionThrower.")
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		test.expect(camera != null, "Player has Camera2D.")
		if camera != null:
			test.expect(camera.position_smoothing_enabled, "Camera2D has position smoothing enabled.")
			test.expect(camera.get("left_barrier_path") != null, "Camera2D has left_barrier_path configured.")
			test.expect(camera.get("right_barrier_path") != null, "Camera2D has right_barrier_path configured.")

	var party: InnerPartyController = level.get_node_or_null("InnerPartyController") as InnerPartyController
	test.expect(party != null, "InnerPartyController is initialized.")
	if party != null:
		test.expect_equal(party.active_character, &"sherry", "Default active character is sherry.")
		party.set_active_character(&"luca")
		test.expect_equal(party.active_character, &"luca", "Active character switches to luca.")
		party.set_active_character(&"sherry")
		test.expect_equal(party.active_character, &"sherry", "Active character switches back to sherry.")

	# Test Zone 0 CurtainGate and Switch
	var z0_switch := level.get_node_or_null("World/Mechanisms/Zone0_Broad1") as InteractiveSwitch
	var z0_curtain := level.get_node_or_null("World/Mechanisms/Zone0_CurtainGate_A") as CurtainGate
	test.expect(z0_switch != null, "Zone 0 Broad1 switch exists.")
	test.expect(z0_curtain != null, "Zone 0 CurtainGate_A exists.")
	if z0_switch != null and z0_curtain != null:
		test.expect(not z0_curtain.is_open, "CurtainGate_A starts closed.")
		z0_switch.activate_switch()
		test.expect(z0_curtain.is_open, "CurtainGate_A opens on switch activate.")

	# Test Zone 1 LightTarget
	var z1_target := level.get_node_or_null("World/Mechanisms/Zone1_LightTarget_A") as LightTarget
	test.expect(z1_target != null, "Zone 1 LightTarget_A exists.")
	if z1_target != null:
		z1_target.trigger_hit()
		test.expect(z1_target.is_lit, "LightTarget_A is lit after hit.")

	var shift_mgr := level.get_node_or_null("DreamShiftManager") as DreamShiftManager
	test.expect(shift_mgr != null, "DreamShiftManager exists in Inner level.")
	if shift_mgr != null:
		test.expect(shift_mgr.is_in_dream(), "DreamShiftManager starts in Dream by default.")
		var state_received: Array[bool] = []
		shift_mgr.dream_state_changed.connect(func(is_d: bool) -> void: state_received.append(is_d))
		shift_mgr.force_shift(false)
		test.expect(shift_mgr.is_in_reality_intrusion(), "DreamShiftManager shifts to Reality Intrusion on force_shift(false).")
		test.expect_equal(state_received.size(), 1, "dream_state_changed signal fired once.")
		test.expect_equal(state_received[0], false, "dream_state_changed signaled false for reality intrusion.")
		shift_mgr.force_shift(true)
		test.expect(shift_mgr.is_in_dream(), "DreamShiftManager returns to Dream state on force_shift(true).")

	var dream_bridge := level.get_node_or_null("World/Mechanisms/Zone3_DreamBridge") as DreamBridge
	test.expect(dream_bridge != null, "Zone 3 DreamBridge platform exists.")

	var thorn_bed := level.get_node_or_null("World/Mechanisms/Zone1_Bed1") as DreamThornBed
	test.expect(thorn_bed != null, "Zone 1 DreamThornBed exists.")

	var stretcher := level.get_node_or_null("World/Mechanisms/Zone3_Stretcher1") as RollingStretcher
	test.expect(stretcher != null, "Zone 3 RollingStretcher exists.")

	var marrow_node := level.get_node_or_null("World/Mechanisms/DreamMarrowNode") as DreamMarrowNode
	var exit_door := level.get_node_or_null("World/Mechanisms/WardExitDoor") as WardExitDoor
	test.expect(marrow_node != null, "Zone 5 DreamMarrowNode exists.")
	test.expect(exit_door != null, "Zone 5 WardExitDoor exists.")
	if marrow_node != null and exit_door != null:
		test.expect(not marrow_node.is_activated, "DreamMarrowNode is initially unactivated.")
		test.expect(not exit_door.is_open, "WardExitDoor is initially closed.")
		marrow_node.activate_node()
		test.expect(marrow_node.is_activated, "DreamMarrowNode is activated after calling activate_node().")
		test.expect(exit_door.is_open, "WardExitDoor is unlocked and opened after marrow node activation.")
		test.expect(level.get("is_ward_cleansed"), "Level is_ward_cleansed is true after marrow activation.")

	# Verify checkpoints are removed (single continuous gauntlet)
	var checkpoints := level.get_node_or_null("World/Checkpoints")
	test.expect(checkpoints == null, "Checkpoints container is removed from Inner level.")

	var portals := level.get_node_or_null("World/Portals")
	test.expect(portals != null, "Portals container exists.")
	if portals != null:
		test.expect(portals.has_node("EntrancePortal"), "EntrancePortal exists.")
		test.expect(portals.has_node("ExitPortal"), "ExitPortal exists.")

	level.free()

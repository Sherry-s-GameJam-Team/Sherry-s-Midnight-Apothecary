extends RefCounted


static func run(test: TestSupport) -> void:
	var lake_scene := load("res://day/levels/lake_bottom/lake.tscn") as PackedScene
	test.expect(lake_scene != null, "Lake Bottom scene loads with the Tide Eye encounter.")
	if lake_scene != null:
		var lake := lake_scene.instantiate()
		var boss := lake.get_node_or_null("boss") as CanvasItem
		var tide_eye := lake.get_node_or_null("boss/TideEye")
		var generator := lake.get_node_or_null("boss/BoxGenerator")
		var completion_ui := lake.get_node_or_null("TaskCompleteUI") as TaskCompleteUI
		test.expect(boss != null, "Boss support container is present and keeps its editor-authored presentation state.")
		test.expect(completion_ui != null, "Defeating the Tide Eye can present the task-complete UI before departure.")
		test.expect(tide_eye is TideEye, "Boss uses the TideEye script-rendered node.")
		test.expect(tide_eye != null, "Ground-impact potion listener has a Tide Eye target.")
		test.expect(generator != null and generator.has_method("activate") and generator.has_method("deactivate"), "Boss box generator is phase-controlled.")
		if tide_eye is TideEye:
			test.expect_equal((tide_eye as TideEye).hits_required, 3, "Tide Eye requires exactly three effective hits.")
			test.expect_equal((tide_eye as TideEye).exposed_seconds, 4.2, "Each exposed Tide Eye window lasts 4.2 seconds.")
			var source: String = str((tide_eye as TideEye).get_script().source_code)
			test.expect("func _draw" in source, "Tide Eye visual is drawn by GDScript.")
			test.expect(not ("Shader" in source or "SpriteFrames" in source or "Texture2D" in source), "Tide Eye script does not depend on boss textures, frames, or shaders.")
		var epilogue_script := load("res://day/levels/lake_bottom/scripts/lake_boss_epilogue.gd") as GDScript
		test.expect(epilogue_script != null and "&\"from_bottom\"" in epilogue_script.source_code, "Tide Eye epilogue routes to the village from_bottom entry.")
		lake.free()

	var chamber_scene := load("res://day/levels/lake_bottom/gate_chamber.tscn") as PackedScene
	test.expect(chamber_scene != null, "Gate Chamber scene loads.")
	if chamber_scene != null:
		var chamber := chamber_scene.instantiate()
		test.expect(chamber.get_node_or_null("EntryPoints/from_home") is Marker2D, "Gate Chamber has a Home travel arrival point.")
		var door := chamber.get_node_or_null("CentralGateDoor") as GateChamberDoor
		test.expect(door != null and door.destination_level == &"home", "Maintenance station central gate returns to Home.")
		chamber.free()

	var progression := load("res://day/levels/lake_bottom/scripts/springburst_potion_progression.gd") as GDScript
	test.expect(progression != null, "Springburst story-to-throwable progression script loads.")
	var progression_data := PlayerData.new()
	SpringburstPotionProgression.grant_story_bottles(progression_data, 4)
	test.expect_equal(int(progression_data.story_items.get(&"springburst_potion_commission", 0)), 4, "Commission bottles begin in the story-item inventory.")
	test.expect(not progression_data.potions.has(&"cyan_potion"), "Commission bottles are not throwable before the boss victory.")
	test.expect(progression_data.is_potion_recipe_unlocked(&"recipe_cyan_springburst") and not progression_data.is_potion_throwable_unlocked(&"cyan_potion"), "Springburst is recorded in the codex before its combat use is unlocked.")
	var unlocked_count := SpringburstPotionProgression.unlock_throwable_after_boss(progression_data)
	test.expect_equal(unlocked_count, 4, "Boss victory converts all four commission bottles.")
	test.expect(progression_data.has_event_flag(&"enzo_remote_supply_unlocked"), "Boss reward keeps the remote-supply flag populated for compatible saves.")
	test.expect(not progression_data.story_items.has(&"springburst_potion_commission"), "Converted bottles leave the story-item inventory.")
	test.expect_equal(progression_data.potion_count(&"cyan_potion"), 4, "Converted Springburst bottles become throwable potion instances.")
	test.expect(progression_data.is_potion_throwable_unlocked(&"cyan_potion"), "Boss victory registers Springburst for throwing.")
	test.expect_equal(progression_data.equipped_potion_ids, [&"", &"", &""], "Boss registration does not auto-equip Springburst.")
	var legacy_data := PlayerData.new()
	legacy_data.add_brewed_potion({"potion_id": "cyan_potion", "instance_uid": "legacy-cyan", "remaining_dose": 1.0})
	legacy_data.equip_potion(0, &"cyan_potion")
	test.expect_equal(SpringburstPotionProgression.enforce_story_item_phase(legacy_data), 1, "Old pre-boss saves migrate early cyan potions back to story items.")
	test.expect(not legacy_data.potions.has(&"cyan_potion") and legacy_data.equipped_potion_ids[0] == &"", "Migration removes early cyan potions from the throwable loadout.")
	var prior_reward_data := PlayerData.new()
	prior_reward_data.set_event_flag(&"springburst_throwable_unlocked")
	SpringburstPotionProgression.unlock_throwable_after_boss(prior_reward_data)
	test.expect(prior_reward_data.has_event_flag(&"enzo_remote_supply_unlocked"), "A save with the earlier throwable reward backfills the newer remote-supply unlock.")
	var cyan_data := load("res://shared/definitions/data/potions/cyan_potion.tres") as PotionData
	test.expect(cyan_data != null and cyan_data.display_name == "涌水药水", "Cyan potion uses the story-correct Springburst display name.")

	var supply_script := load("res://day/systems/remote_potion_supply.gd") as GDScript
	test.expect(supply_script != null, "Remote potion supply system loads.")
	var supply_data := PlayerData.new()
	supply_data.add_brewed_potion({"potion_id": "blue_potion", "instance_uid": "backpack-blue", "remaining_dose": 1.0})
	supply_data.add_brewed_potion({"potion_id": "green_potion", "instance_uid": "equipped-green", "remaining_dose": 0.35})
	supply_data.equip_potion(0, &"green_potion")
	var supply := RemotePotionSupply.new()
	supply.setup(supply_data)
	supply_data.potions.erase(&"blue_potion")
	test.expect_equal(supply.advance_supply_time(90.0), &"", "Remote supply remains inactive before the day-two opening unlock.")
	supply_data.set_event_flag(&"enzo_remote_supply_unlocked")
	test.expect_equal(supply.advance_supply_time(90.0), &"", "Remote supply remains inactive outside Golden Cliff and later levels.")
	supply.set_level_scope_active(true)
	test.expect_equal(supply.advance_supply_time(1.0), &"green_potion", "Remote supply begins restoring the equipped current bottle immediately and gradually.")
	var green_instances: Array = supply_data.potions.get(&"green_potion", [])
	test.expect_float_close(float(green_instances[0].get("remaining_dose", 0.0)), 0.36, 0.001, "Equipped partial bottle gains one percentage point per second instead of jumping to full.")
	test.expect_equal(supply.advance_supply_time(64.0), &"green_potion", "Gradual restoration continues until the current throw bottle is full.")
	green_instances = supply_data.potions.get(&"green_potion", [])
	test.expect_float_close(float(green_instances[0].get("remaining_dose", 0.0)), 1.0, 0.001, "Equipped current bottle eventually reaches 100 percent.")
	test.expect_equal(supply.advance_supply_time(44.0), &"", "New-bottle timing starts only after equipped current bottles are full.")
	test.expect_equal(supply.advance_supply_time(1.0), &"blue_potion", "After equipped percentages are full, a previously carried backpack potion is replenished even when it is not equipped.")
	test.expect_equal(supply_data.potion_count(&"blue_potion"), 1, "Remote supply adds one full bottle to the backpack.")
	supply.free()
	var capped_data := PlayerData.new()
	for index in range(4):
		capped_data.add_brewed_potion({"potion_id": "red_potion", "instance_uid": "cap-red-%d" % index, "remaining_dose": 1.0})
	capped_data.set_event_flag(&"enzo_remote_supply_unlocked")
	var capped_supply := RemotePotionSupply.new()
	capped_supply.setup(capped_data)
	capped_supply.set_level_scope_active(true)
	test.expect_equal(capped_supply.advance_supply_time(90.0), &"", "A full four-bottle stack receives no fifth bottle.")
	test.expect_equal(capped_data.potion_count(&"red_potion"), 4, "Remote supply bottle cap remains four.")
	capped_supply.free()
	var runtime_source := FileAccess.get_file_as_string("res://day/day_runtime.gd")
	var supply_source := FileAccess.get_file_as_string("res://day/systems/remote_potion_supply.gd")
	test.expect(not runtime_source.contains("remote_potion_replenished") and not supply_source.contains("potion_replenished"), "Remote supply completion signals cannot trigger legacy delivery Hint UI messages.")
	test.expect(not runtime_source.contains("远程补给已送达") and not supply_source.contains("TopHintUI") and not supply_source.contains("push_text"), "Remote supply contains no Hint UI delivery path.")
	var runtime_scene := load("res://day/day_runtime.tscn") as PackedScene
	var day_runtime: DayRuntime
	if runtime_scene != null:
		day_runtime = runtime_scene.instantiate() as DayRuntime
	if day_runtime != null:
		var market_level := load("res://day/levels/market/town/town_level.tres") as LevelData
		var golden_level := load("res://day/levels/golden_cliff/golden_cliff_level.tres") as LevelData
		var lake_bottom_level := load("res://day/levels/lake_bottom/lake_bottom_level.tres") as LevelData
		test.expect(not day_runtime.call("_is_remote_supply_level", market_level), "Remote supply excludes levels before Golden Cliff.")
		test.expect(day_runtime.call("_is_remote_supply_level", golden_level), "Remote supply begins in Golden Cliff.")
		test.expect(day_runtime.call("_is_remote_supply_level", lake_bottom_level), "Remote supply remains active in later levels.")
		day_runtime.free()

	var map_scene := load("res://day/interactables/map_switch/data/map.tscn") as PackedScene
	if map_scene != null:
		var map := map_scene.instantiate()
		var anchor := map.get_node_or_null("AnchorPoints/Anchor04") as MapSwitchAnchor
		test.expect(anchor != null and anchor.destination_id == &"gate_chamber", "Anchor04 routes to the maintenance station.")
		map.free()

	var village_scene := load("res://day/levels/golden_cliff/village/village.tscn") as PackedScene
	test.expect(village_scene != null, "Village scene loads for the Tide Eye return.")
	if village_scene != null:
		var village := village_scene.instantiate()
		test.expect(village.get_node_or_null("EntryPoints/from_bottom") is Marker2D, "Tide Eye return places Sherry at the village from_bottom marker.")
		var foreground := village.get_node_or_null("CS") as Parallax2D
		test.expect(foreground != null, "Boat and rope share the village foreground camera layer.")
		var boat := village.get_node_or_null("CS/saved/Boat") as Sprite2D
		test.expect(boat is VillageBoatBob, "The returned boat is stored under saved and has lake-swell motion.")
		var water_loop := village.get_node_or_null("CS/saved/IdleLoop") as AnimatedSprite2D
		test.expect(water_loop != null and water_loop.animation == &"idle_loop", "The dock water idle loop is stored under Village/saved.")
		test.expect(village.get_node_or_null("CS/rope") is Node2D, "Collectable ropes share the boat's foreground camera layer.")
		var lake_return := village.get_node_or_null("LakeReturn") as VillageLakeReturn
		test.expect(lake_return != null and lake_return.dialogue_resource != null, "Village has the Tide Eye reunion dialogue controller.")
		if lake_return != null and lake_return.dialogue_resource != null:
			var dialogue_source := lake_return.dialogue_resource.resource_path
			test.expect(dialogue_source.ends_with("village_lake_return.dialogue"), "Village return controller uses the dock reunion dialogue resource.")
		var departure := village.get_node_or_null("day3/to Red") as VillageDayThreeDeparture
		test.expect(departure != null and departure.dialogue_resource != null, "Village Day 3 has the E-key Crimson Vale departure interaction.")
		village.free()

	var voyage_scene := load("res://day/levels/golden_cliff/village/village_red_voyage.tscn") as PackedScene
	test.expect(voyage_scene != null, "Standalone five-second village-to-Red voyage scene loads.")
	if voyage_scene != null:
		var voyage := voyage_scene.instantiate()
		test.expect(voyage is VillageRedVoyage, "Voyage scene is driven by the village red-voyage controller.")
		test.expect(voyage.get_node_or_null("BoatGroup/SherryRider") is Sprite2D and voyage.get_node_or_null("BoatGroup/DashiyuRider") is Sprite2D, "Voyage keeps editable Sherry and Dashiyu rider sprites.")
		voyage.free()

	var crimson_scene := load("res://day/levels/Crimson Vale/crimson_vale.tscn") as PackedScene
	test.expect(crimson_scene != null, "Crimson Vale scene loads for village-voyage arrival.")
	if crimson_scene != null:
		var crimson := crimson_scene.instantiate() as CrimsonValeLevel
		test.expect(crimson != null and crimson.village_arrival_dialogue != null, "Crimson Vale has the Danfeng Station arrival dialogue.")
		test.expect(crimson.get_node_or_null("EntryPoints/from_village") is Marker2D, "Crimson Vale keeps the from_village arrival marker.")
		crimson.free()

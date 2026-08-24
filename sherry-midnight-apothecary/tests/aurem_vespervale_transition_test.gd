extends RefCounted


static func run(test: TestSupport) -> void:
	var empty_data := PlayerData.new()
	test.expect(not AuremPostBossSequence.should_spawn_post_boss_herbs(empty_data), "Post-boss herbs stay hidden before Helion is cleared.")
	empty_data.tutorial_flags[&"aurem_clockyard_farm_cleansed"] = true
	empty_data.tutorial_flags[&"aurem_clockyard_tower_synchronized"] = true
	test.expect(not AuremPostBossSequence.should_spawn_post_boss_herbs(empty_data), "Farm cleansing and clock synchronization alone do not unlock post-boss herbs.")
	empty_data.tutorial_flags[&"aurem_helion_cleared"] = true
	test.expect(AuremPostBossSequence.should_spawn_post_boss_herbs(empty_data), "Helion's cleared flag unlocks the three post-boss herbs.")
	empty_data.set_event_flag(&"aurem_post_boss_harvest_complete")
	test.expect(not AuremPostBossSequence.should_spawn_post_boss_herbs(empty_data), "Completed harvest story does not respawn its herbs.")

	var clockyard_packed := load("res://day/levels/Aurem Clockyard/aurem_clockyard.tscn") as PackedScene
	test.expect(clockyard_packed != null, "Aurem Clockyard post-boss scene loads.")
	if clockyard_packed != null:
		var clockyard := clockyard_packed.instantiate()
		var director := clockyard.get_node_or_null("HerbSpawnDirector") as HerbSpawnDirector
		test.expect(director != null, "Clockyard contains HerbSpawnDirector.")
		if director != null:
			test.expect_equal(director.spawn_point_count(), 3, "The post-boss harvest uses exactly three authored points.")
		test.expect(clockyard.has_node("PostBossSequence"), "Clockyard contains the post-boss story director.")
		test.expect(clockyard.has_node("Luca"), "Clockyard contains an entity Luca follower.")
		test.expect(clockyard.has_node("PostBossSequence/VioletRoadLamp"), "Clockyard contains the violet route lamp.")
		clockyard.free()

	var level_data := load("res://day/levels/Aurem Clockyard/aurem_vespervale_transition_level.tres") as LevelData
	test.expect(level_data != null, "Aurem-to-Vespervale transition LevelData loads.")
	if level_data != null:
		test.expect_equal(level_data.id, &"aurem_vespervale_transition", "Transition level has the registered id.")
		test.expect(not level_data.show_title_card, "Transition suppresses the normal title card.")

	var packed := load("res://day/levels/Aurem Clockyard/aurem_vespervale_transition.tscn") as PackedScene
	test.expect(packed != null, "Aurem-to-Vespervale transition scene loads.")
	if packed == null:
		return
	var level := packed.instantiate()
	var background := level.get_node_or_null("Background") as Sprite2D
	var player := level.get_node_or_null("Player") as CharacterBody2D
	test.expect(background != null and background.texture != null, "Transition uses its continuous background texture.")
	if background != null and background.texture != null:
		test.expect_equal(background.texture.resource_path, "res://day/levels/Aurem Clockyard/transBG.png", "Transition uses transBG.png.")
		test.expect_equal(background.scale.x, 1.5, "Transition background is extended to 1.5x width.")
	test.expect(player != null, "Transition contains Sherry.")
	if player != null:
		test.expect_equal(float(player.get("walk_speed")), 50.0, "Transition walk speed is 50 px/s.")
		test.expect_equal(float(player.get("run_speed")), 50.0, "Transition run speed cannot bypass the pacing.")
	test.expect(level.has_node("Luca"), "Transition contains entity Luca.")
	test.expect(level.has_node("LucaFollow"), "Transition keeps Luca's local follow controller.")
	var seconds := AuremVespervaleTransitionLevel.expected_walk_seconds()
	test.expect(seconds >= 30.0 and seconds <= 40.0, "Full-speed transition takes approximately 30-40 seconds.")
	level.free()

	var dialogue := load("res://day/levels/Aurem Clockyard/aurem_post_boss.dialogue")
	test.expect(dialogue != null, "Post-boss harvest and optional road-loop dialogue load.")

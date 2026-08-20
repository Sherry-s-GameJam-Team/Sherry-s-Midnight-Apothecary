extends RefCounted


static func run(test: TestSupport) -> void:
	var packed := load("res://day/levels/grassland/level.tscn") as PackedScene
	test.expect(packed != null, "Emerald Field level scene can be loaded.")
	if packed == null:
		return
	var level := packed.instantiate() as EmeraldFieldLevel
	test.expect(level != null, "Emerald Field uses its project-integrated level controller.")
	if level == null:
		return
	test.expect(level.start_corrupted, "Emerald Field remains in its corrupted state after the floating-island cinematic.")
	var player := level.get_node("Player") as CharacterBody2D
	var entry := level.get_node("EntryPoints/default") as Marker2D
	test.expect(player != null, "Emerald Field contains the production Player node.")
	test.expect(player.get_script() == load("res://shared/player/day_player_controller.gd"), "Emerald Field reuses the current Sherry controller.")
	test.expect(player.has_node("SherryCollision"), "Emerald Field reuses Sherry's outdoor collision.")
	test.expect(player.has_node("SherryPresentation"), "Emerald Field reuses Sherry's presentation and animations.")
	test.expect(player.has_node("PotionThrower"), "Emerald Field installs the current potion player system.")
	test.expect(player.has_node("Camera2D"), "Emerald Field installs the current player Camera2D.")
	test.expect(player.is_in_group("player"), "Emerald Field hazards recognize the current Player through the player group.")
	test.expect_equal(entry.position, level.get_node("PlayerSpawn").position, "DayRuntime entry and hazard respawn use the same position.")
	test.expect(level.get_node_or_null("DemoPlayer") == null, "The standalone DemoPlayer is not deployed.")
	test.expect_equal(level.get_node("Platforms").get_child_count(), 16, "All 16 packaged platform nodes are deployed.")
	test.expect(level.get_node("Hazards/PoisonGasA").has_method("reset_hazard"), "Packaged poison-gas behavior is connected.")
	test.expect(level.get_node("Platforms/Collapse01").has_method("reset_hazard"), "Packaged collapse-platform behavior is connected.")
	var goal := level.get_node("Goal")
	test.expect(goal.has_signal("minigame_requested"), "The old travel-gate Goal exposes the miasma-purifier interaction.")
	test.expect(goal.has_method("set_available"), "The Goal can remain unavailable after purification is saved.")
	var minigame_packed := load("res://minigames/minigames/miasma_purifier/scenes/miasma_purifier_osu_minigame.tscn") as PackedScene
	test.expect(minigame_packed != null, "The integrated miasma purifier scene can be loaded.")
	if minigame_packed != null:
		var minigame := minigame_packed.instantiate()
		test.expect(minigame.has_signal("minigame_completed"), "The osu purifier reports completion to the level.")
		test.expect(minigame.get_node_or_null("World/AnchorPoints") != null, "The osu purifier includes its click-anchor route.")
		minigame.free()
	level.free()

extends RefCounted


static func run(test: TestSupport) -> void:
	var scene := load("res://night/levels/home/luca_night_npc.tscn") as PackedScene
	test.expect(scene != null, "LucaNightNPC scene loads successfully.")
	if scene == null:
		return

	var npc := scene.instantiate() as LucaNightNPC
	test.expect(npc != null, "LucaNightNPC instantiates as expected type.")
	if npc == null:
		return

	var tree := Engine.get_main_loop() as SceneTree
	var player_data := PlayerData.new()

	# Test reward granting logic
	test.expect_equal(player_data.inventory.get(&"dew_flask_herb", 0), 0, "Initial dew_flask_herb count is 0.")
	test.expect(not bool(player_data.tutorial_flags.get("night_luca_intro_completed", false)), "Intro completed flag is initially false.")
	test.expect(not bool(player_data.tutorial_flags.get("night_luca_dew_flask_given", false)), "Reward granted flag is initially false.")

	# Mock parent with get_player_data
	var mock_parent := Node2D.new()
	mock_parent.set_script(load("res://night/levels/home/night_home.gd"))
	mock_parent.set("_standalone_player_data", player_data)
	tree.root.add_child(mock_parent)
	mock_parent.add_child(npc)

	# Verify herb reward grant
	npc.call("_grant_herb_reward")
	test.expect_equal(player_data.inventory.get(&"dew_flask_herb", 0), 2, "Granting reward adds 2 dew_flask_herb to inventory.")
	test.expect(bool(player_data.tutorial_flags.get("night_luca_dew_flask_given", false)), "Reward flag is set.")

	# Granting again does not duplicate
	npc.call("_grant_herb_reward")
	test.expect_equal(player_data.inventory.get(&"dew_flask_herb", 0), 2, "Granting reward again does not duplicate items.")

	# Verify guidance start and completion
	var tracker := {"started": false, "completed": false}
	npc.guidance_started.connect(func() -> void: tracker["started"] = true)
	npc.guidance_completed.connect(func() -> void: tracker["completed"] = true)

	npc.call("_start_alchemy_guidance")
	test.expect(tracker["started"], "Guidance started signal was emitted.")
	test.expect(npc.get("_guiding_to_alchemy"), "Guiding to alchemy state is active.")

	npc.call("_on_alchemy_opened")
	test.expect(tracker["completed"], "Guidance completed signal was emitted when alchemy opens.")
	test.expect(not npc.get("_guiding_to_alchemy"), "Guiding to alchemy state is cleared.")

	mock_parent.free()


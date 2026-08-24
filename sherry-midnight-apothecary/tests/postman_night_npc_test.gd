extends RefCounted


static func run(test: TestSupport) -> void:
	# 1. Verify portrait database resolution
	var postman_tex: Texture2D = DialoguePortraitDatabase.get_portrait_texture("钟庭邮差")
	test.expect(postman_tex != null, "钟庭邮差 resolves to a valid portrait texture.")
	var postman_alias_tex: Texture2D = DialoguePortraitDatabase.get_portrait_texture("postman")
	test.expect(postman_alias_tex != null, "postman alias resolves to a valid portrait texture.")

	# 2. Verify Scene loading & instantiation
	var scene := load("res://night/levels/home/postman_night_npc.tscn") as PackedScene
	test.expect(scene != null, "PostmanNightNPC scene loads successfully.")
	if scene == null:
		return

	var postman_script := load("res://night/levels/home/postman_night_npc.gd") as Script
	var npc := scene.instantiate() as Node
	test.expect(npc != null, "PostmanNightNPC instantiates successfully.")
	test.expect(npc.get_script() == postman_script, "PostmanNightNPC has correct script attached.")
	if npc == null:
		return

	var tree := Engine.get_main_loop() as SceneTree
	var player_data := PlayerData.new()

	# Add an orange potion to player_data
	player_data.add_brewed_potion({
		"instance_uid": "test_orange_1",
		"potion_id": &"orange_potion",
		"display_name": "橙风活化药水",
		"remaining_dose": 1.0,
		"concentration": 1.0,
		"primary_tag": &"activation",
	})
	test.expect_equal(player_data.potion_count(&"orange_potion"), 1, "Player holds 1 orange potion initially.")

	# Mock parent with get_player_data
	var mock_parent := Node2D.new()
	mock_parent.set_script(load("res://night/levels/home/night_home.gd"))
	mock_parent.set("_standalone_player_data", player_data)
	tree.root.add_child(mock_parent)
	mock_parent.add_child(npc)

	# 3. Test day filtering
	npc.configure_for_day(1)
	test.expect(not npc.visible, "Postman is hidden on Day 1.")
	npc.configure_for_day(2)
	test.expect(not npc.visible, "Postman is hidden on Day 2.")
	npc.configure_for_day(3)
	test.expect(npc.visible, "Postman is visible on Day 3.")

	# 4. Test delivery logic
	test.expect(not player_data.has_event_flag(&"special_orange_customer_completed"), "Event completion flag initially false.")
	npc.call("_deliver_orange_potion")

	test.expect_equal(player_data.potion_count(&"orange_potion"), 0, "Delivering orange potion consumes 1 bottle.")
	test.expect(player_data.has_event_flag(&"aurem_clockyard_portal_unlocked"), "Aurem Clockyard portal flag is set.")
	test.expect(player_data.has_event_flag(&"aurem_portal_key_calibrated"), "Portal key calibrated flag is set.")
	test.expect(player_data.has_unlocked_level(&"aurem_clockyard"), "Aurem Clockyard level is unlocked.")
	test.expect(player_data.is_potion_recipe_unlocked(&"recipe_orange_activation_draft"), "Orange potion recipe is unlocked.")
	test.expect(player_data.codex_unlocked_function_ids.has(&"func_vigor_boost"), "Codex function func_vigor_boost is unlocked.")
	test.expect(player_data.codex_unlocked_function_ids.has(&"func_muscle_active"), "Codex function func_muscle_active is unlocked.")
	test.expect(player_data.is_potion_throwable_unlocked(&"orange_potion"), "Orange potion is throwable unlocked.")

	mock_parent.free()

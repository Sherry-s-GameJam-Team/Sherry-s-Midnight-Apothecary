extends RefCounted


static func run(test: TestSupport) -> void:
	var menu_scene := load("res://menu/menu.tscn") as PackedScene
	test.expect(menu_scene != null, "Menu scene loads.")
	if menu_scene == null:
		return
	var menu := menu_scene.instantiate() as MenuController
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(menu)
	menu.configure({})
	var continue_button := menu.get_node("MenuUILayer/MenuUI/MenuButtons/ContinueButton") as Button
	test.expect(continue_button.disabled, "Continue is disabled without a save.")
	var resolver := menu.get_node("SkyProfileResolver") as SkyProfileResolver
	test.expect_equal(resolver.profiles.size(), 6, "Five milestone profiles and one night profile are registered.")
	test.expect_equal(resolver.get_profile_for_menu(false, GameFlow.Mode.DAY).profile_id, &"day_01_default", "A new game uses the clear daytime sky.")
	test.expect_equal(resolver.get_profile_for_menu(true, GameFlow.Mode.DAY).profile_id, &"day_01_default", "A daytime save keeps the clear daytime sky.")
	test.expect_equal(resolver.get_profile_for_menu(true, GameFlow.Mode.NIGHT).profile_id, &"night_default", "Only a night save selects the night sky.")
	test.expect_equal(resolver.get_profile_for_day(1).profile_id, &"day_01_default", "Day 1 resolves its default sky.")
	test.expect_equal(resolver.get_profile_for_day(8).profile_id, &"day_07_warning", "Days after 7 use the warning milestone.")
	test.expect_equal(resolver.get_profile_for_day(14).profile_id, &"day_14_anomaly", "Day 14 resolves the anomaly sky.")
	test.expect_equal(resolver.get_profile_for_day(29).profile_id, &"day_21_disaster", "Day 29 retains the disaster sky.")
	test.expect_equal(resolver.get_profile_for_day(30).profile_id, &"day_30_finale", "Day 30 resolves the finale sky.")
	var override := resolver.get_profile_for_day(1, {"sky_profile_id": "day_14_anomaly"})
	test.expect_equal(override.profile_id, &"day_14_anomaly", "World state can override the day mapping.")
	menu.free()

	var host := Node.new()
	tree.root.add_child(host)
	var runtime_slot := Node.new()
	host.add_child(runtime_slot)
	var flow := GameFlow.new()
	host.add_child(flow)
	flow.configure(runtime_slot, PlayerData.new())
	test.expect(flow.start_new_game(&"bedroom", true, true), "Menu startup can request the bedroom level.")
	var day_runtime := flow.current_runtime as DayRuntime
	test.expect(day_runtime != null, "Bedroom startup creates DayRuntime.")
	if day_runtime != null:
		test.expect_equal(day_runtime.current_level.id, &"bedroom", "Bedroom is the selected initial level.")
		var executor := day_runtime.current_level_instance.get_node("SleepToWakeExecutor") as AnimationPresentationExecutor
		var player := day_runtime.current_level_instance.get_node("Player") as CharacterBody2D
		test.expect(not executor.auto_start, "Bedroom wake-up waits for the menu bridge.")
		test.expect(not player.is_physics_processing(), "Player physics is locked before the roof reveals the bedroom.")
		var bedroom_camera := player.get_node("Camera2D") as Camera2D
		test.expect(bedroom_camera.can_process(), "Bedroom camera remains active while player input is locked.")
		test.expect(not day_runtime.current_level.show_title_card, "Bedroom does not display a level title card.")
		test.expect(day_runtime.switch_to_level("home", &"bedroomdoor"), "Bedroom exit can load Home at its bedroom door.")
		var home_director := day_runtime.current_level_instance.get_node("HomeCameraDirector") as HomeCameraDirector
		var home_camera := day_runtime.current_level_instance.get_node("Player/Camera2D") as Camera2D
		test.expect(home_director.is_camera_in_bedroom(), "Home camera adopts bedroom bounds for the bedroom-door entry.")
		test.expect(home_camera.global_position.x < 0.0, "Home camera starts beside the bedroom player instead of panning toward x=0.")
		test.expect_equal(home_camera.limit_right, home_director.bedroom_right_limit, "Bedroom entry applies the bedroom camera limit immediately.")
		test.expect(not day_runtime.current_level.show_title_card, "Home does not display a level title card.")
		var home_player := day_runtime.current_level_instance.get_node("Player") as CharacterBody2D
		home_player.global_position.x = 400.0
		for _step in range(20):
			home_director._process(0.1)
		test.expect(not home_director.is_camera_in_bedroom(), "Crossing into Home returns camera ownership to the main room.")
		test.expect_equal(home_camera.limit_left, 0, "Main-room camera restores its original left limit.")
		test.expect(home_camera.global_position.x > 0.0, "Home camera follows into the room instead of sticking at x=0.")
	test.expect(flow.resume_game(7, GameFlow.Mode.NIGHT), "Night saves resume through their original runtime mode.")
	test.expect(flow.current_runtime is NightRuntime, "Night resume does not force the bedroom intro.")
	host.free()

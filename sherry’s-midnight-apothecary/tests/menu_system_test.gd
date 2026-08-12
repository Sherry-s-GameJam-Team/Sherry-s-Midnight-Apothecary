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
	var tree_silhouette := menu.get_node("World/SilhouetteLayers/TreeSilhouette") as Sprite2D
	var bird_silhouette := menu.get_node("World/SilhouetteLayers/BirdSilhouette") as Sprite2D
	var silhouette_director := menu.get_node("MenuSilhouetteDirector") as MenuSilhouetteDirector
	var roof_marker := menu.get_node("World/RoofTransitionPoint") as Marker2D
	test.expect_equal(tree_silhouette.texture.resource_path, "res://art/effects/tree.png", "Menu tree uses the supplied silhouette texture.")
	test.expect_equal(bird_silhouette.texture.resource_path, "res://art/effects/bird.png", "Menu birds use the supplied silhouette texture.")
	test.expect_equal(tree_silhouette.scale, bird_silhouette.scale, "Tree and bird masks share one canvas scale.")
	var tree_bottom := tree_silhouette.global_position.y + tree_silhouette.texture.get_height() * tree_silhouette.global_scale.y
	var room_mask_edge: float = roof_marker.global_position.y + menu.get_viewport().get_visible_rect().size.y * 0.5
	test.expect_float_close(tree_bottom, room_mask_edge + silhouette_director.roof_mask_overlap, 0.1, "Tree mask overlaps the room mask at the final frame bottom edge.")
	test.expect_float_close(MenuCameraDirector.ease_uniform_accel_decel(0.25), 0.125, 0.0001, "Camera uses constant acceleration in the first half.")
	test.expect_float_close(MenuCameraDirector.ease_uniform_accel_decel(0.5), 0.5, 0.0001, "Camera reaches half distance at half time.")
	test.expect_float_close(MenuCameraDirector.ease_uniform_accel_decel(0.75), 0.875, 0.0001, "Camera uses symmetric constant deceleration in the second half.")
	test.expect(not bird_silhouette.visible, "Bird flock stays hidden while the menu is idle.")
	test.expect(silhouette_director.get_bird_start_x() > tree.root.get_viewport().get_visible_rect().size.x * 0.5, "Bird flock starts completely beyond the right edge.")
	test.expect(silhouette_director.get_bird_end_x() < -tree.root.get_viewport().get_visible_rect().size.x * 0.5, "Bird flock finishes completely beyond the left edge.")
	var bird_material := bird_silhouette.material as ShaderMaterial
	test.expect(bird_material != null and bird_material.shader.resource_path == "res://menu/shaders/menu_bird_trail.gdshader", "Bird flock uses the horizontal afterimage shader.")
	test.expect_equal(bird_material.get_shader_parameter("trail_offsets_px"), Vector3(18, 36, 54), "Bird trail uses the approved three soft offsets.")
	test.expect(silhouette_director.play(), "Bird flight starts once from the idle state.")
	test.expect(not silhouette_director.play(), "A running bird flight rejects duplicate playback.")
	for silhouette_path: NodePath in [
		NodePath("World/DistantForest"),
		NodePath("World/TreeCanopyForeground"),
		NodePath("World/ApothecaryHill"),
		NodePath("World/RoofForeground"),
	]:
		var silhouette := menu.get_node(silhouette_path) as CanvasItem
		test.expect(not silhouette.visible, "Temporary menu silhouette is disabled: %s" % silhouette_path)
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
	for viewport_size: Vector2i in [Vector2i(1280, 800), Vector2i(1680, 720)]:
		var preview_viewport := SubViewport.new()
		preview_viewport.size = viewport_size
		tree.root.add_child(preview_viewport)
		var preview_menu := menu_scene.instantiate() as MenuController
		preview_viewport.add_child(preview_menu)
		var preview_tree := preview_menu.get_node("World/SilhouetteLayers/TreeSilhouette") as Sprite2D
		var preview_director := preview_menu.get_node("MenuSilhouetteDirector") as MenuSilhouetteDirector
		var preview_roof := preview_menu.get_node("World/RoofTransitionPoint") as Marker2D
		var scaled_width := preview_tree.texture.get_width() * preview_tree.global_scale.x
		var scaled_bottom := preview_tree.global_position.y + preview_tree.texture.get_height() * preview_tree.global_scale.y
		var expected_bottom: float = preview_roof.global_position.y + viewport_size.y * 0.5 + preview_director.roof_mask_overlap
		test.expect_float_close(scaled_width, viewport_size.x, 0.1, "Tree canvas spans the full viewport width at %s." % viewport_size)
		test.expect_float_close(scaled_bottom, expected_bottom, 0.1, "Tree canvas overlaps the room mask at %s." % viewport_size)
		preview_viewport.free()

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
		var day_console_layer := day_runtime.get_node("DeveloperConsoleLayer") as CanvasLayer
		test.expect(day_console_layer.layer > 210, "The daytime developer console renders above the shared alchemy interface.")
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
		var home_equip := day_runtime.current_level_instance.get_node("Equip") as AlchemyStation
		test.expect_equal(home_equip.alchemy_scene.resource_path, "res://night/alchemy/alchemy_runtime.tscn", "Day Home Equip uses the shared AlchemyRuntime scene.")
		var home_camera := day_runtime.current_level_instance.get_node("Player/Camera2D") as Camera2D
		var home_player := day_runtime.current_level_instance.get_node("Player") as CharacterBody2D
		var home_player_sprite := home_player.get_node("SherryPresentation/SherrySprite") as Node2D
		var bedroom_door_entry := day_runtime.current_level_instance.get_node("EntryPoints/bedroomdoor") as Marker2D
		test.expect_float_close(home_player.global_position.y, bedroom_door_entry.global_position.y, 0.01, "Bedroom exit places the Home player at the grounded marker without an airborne offset.")
		test.expect(home_player_sprite.position.y > 0.0, "Home depth scaling anchors Sherry's feet instead of lifting them from the floor.")
		test.expect(home_director.is_camera_in_bedroom(), "Home camera adopts bedroom bounds for the bedroom-door entry.")
		test.expect(home_camera.global_position.x < 0.0, "Home camera starts beside the bedroom player instead of panning toward x=0.")
		test.expect_equal(home_camera.limit_right, home_director.bedroom_right_limit, "Bedroom entry applies the bedroom camera limit immediately.")
		test.expect(not day_runtime.current_level.show_title_card, "Home does not display a level title card.")
		# This suite verifies the baseline room-camera handoff. The dedicated Home
		# intro suite covers the first-day cinematic override.
		day_runtime.get_player_data().tutorial_flags[HomeDayOneIntro.COMPLETED_FLAG] = true
		home_player.global_position.x = 400.0
		for _step in range(20):
			home_director._process(0.1)
		test.expect(not home_director.is_camera_in_bedroom(), "Crossing into Home returns camera ownership to the main room.")
		test.expect_equal(home_camera.limit_left, 0, "Main-room camera restores its original left limit.")
		test.expect(home_camera.global_position.x > 0.0, "Home camera follows into the room instead of sticking at x=0.")
	test.expect(flow.resume_game(7, GameFlow.Mode.NIGHT), "Night saves resume through their original runtime mode.")
	test.expect(flow.current_runtime is NightRuntime, "Night resume does not force the bedroom intro.")
	host.free()

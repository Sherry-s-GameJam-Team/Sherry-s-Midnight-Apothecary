extends RefCounted

const GARDEN_SCRIPT := preload("res://day/levels/Vespervale/garden.gd")


static func run(test: TestSupport) -> void:
	var level_data := load("res://day/levels/Vespervale/vespervale_garden_level.tres") as LevelData
	test.expect(level_data != null, "Vespervale Garden LevelData resource can be loaded.")
	if level_data != null:
		test.expect_equal(level_data.id, &"vespervale_garden", "LevelData id is vespervale_garden.")
		test.expect(level_data.content_scene != null, "LevelData content_scene is assigned.")
		test.expect_equal(level_data.default_entry_id, &"default", "Default entry id is default.")
		test.expect(level_data.display_name.length() > 0, "Display name is configured.")
		test.expect(level_data.disaster_name.length() > 0, "Disaster name is configured.")

	var packed := load("res://day/levels/Vespervale/garden.tscn") as PackedScene
	test.expect(packed != null, "Vespervale Garden scene can be loaded.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	test.expect(level != null, "Vespervale Garden scene instantiates.")
	if level == null:
		return

	test.expect(level is DayLevelEnvironment, "Garden root inherits from DayLevelEnvironment.")

	var player: CharacterBody2D = level.get_node_or_null("Player") as CharacterBody2D
	test.expect(player != null, "Vespervale Garden contains Player.")
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

	var entry_points: Node = level.get_node_or_null("EntryPoints")
	test.expect(entry_points != null, "EntryPoints node exists.")
	if entry_points != null:
		test.expect(entry_points.has_node("default"), "default entry exists.")
		test.expect(entry_points.has_node("from_home"), "from_home entry exists.")
		test.expect(entry_points.has_node("garden"), "garden entry exists.")
		test.expect(entry_points.has_node("church"), "church entry exists.")

	var bg: Node = level.get_node_or_null("Background")
	test.expect(bg != null, "Background node exists.")
	if bg != null:
		var has_parallax_repeat := false
		for child in bg.get_children():
			if child is Parallax2D:
				var p2d := child as Parallax2D
				if p2d.repeat_size != Vector2.ZERO:
					has_parallax_repeat = true
		test.expect(not has_parallax_repeat, "Background does not use repeating scroll.")

		var fs: Node = bg.get_node_or_null("FS")
		test.expect(fs != null, "FS background node exists.")

	var portals: Node = level.get_node_or_null("World/Portals")
	test.expect(portals != null, "Portals container exists.")
	if portals != null:
		test.expect(portals.has_node("EntrancePortal"), "EntrancePortal exists.")
		test.expect(portals.has_node("ChurchPortal"), "ChurchPortal exists.")

	var bounds: Node = level.get_node_or_null("WorldBounds")
	test.expect(bounds != null, "WorldBounds container exists.")
	if bounds != null:
		test.expect(bounds.has_node("Ground"), "Ground collider exists.")
		test.expect(bounds.has_node("LeftBarrier"), "LeftBarrier collider exists.")
		test.expect(bounds.has_node("RightBarrier"), "RightBarrier collider exists.")

	var debug_ui := level.get_node_or_null("DebugUI")
	test.expect(debug_ui != null, "DebugUI CanvasLayer exists.")
	if debug_ui != null:
		test.expect(debug_ui.has_node("DeveloperConsole"), "DeveloperConsole exists under DebugUI.")

	var pause_menu_layer := level.get_node_or_null("PauseMenuLayer")
	test.expect(pause_menu_layer != null, "PauseMenuLayer exists.")
	if pause_menu_layer != null:
		test.expect(pause_menu_layer.has_node("PauseMenu"), "PauseMenu exists under PauseMenuLayer.")

	var day_five_intro := level.get_node_or_null("IssueDay5") as VespervaleDayFiveIntro
	test.expect(day_five_intro != null, "Garden contains the day-five first-arrival presentation.")
	if day_five_intro != null:
		test.expect(day_five_intro.has_node("walkstart"), "Day-five presentation has a left-side walk start marker.")
		test.expect(day_five_intro.has_node("walkend"), "Day-five presentation keeps the authored walkend marker.")
		test.expect(day_five_intro.has_node("SerenaIllusion"), "Day-five presentation has Serena's world illusion.")
		test.expect(day_five_intro.dialogue_resource != null, "Day-five presentation has its dialogue resource.")
		test.expect(day_five_intro.serena_portrait != null, "Day-five presentation has Serena's portrait.")
		if day_five_intro.serena_portrait != null:
			test.expect_equal(day_five_intro.serena_portrait.resource_path, "res://characters/Serena/standee.png", "Serena uses the requested standee portrait.")

	test.expect(VespervaleDayFiveIntro.should_present(5, null), "The first-path presentation is eligible on day 5.")
	test.expect(not VespervaleDayFiveIntro.should_present(4, null), "The first-path presentation is not eligible before day 5.")
	var completed_data := PlayerData.new()
	completed_data.set_event_flag(VespervaleDayFiveIntro.COMPLETE_FLAG)
	test.expect(not VespervaleDayFiveIntro.should_present(5, completed_data), "The completed first-path presentation does not replay.")
	test.expect(VespervaleDayFiveIntro.should_follow(5, completed_data), "Luca follows Sherry after the day-five event completes.")
	test.expect(not VespervaleDayFiveIntro.should_follow(4, completed_data), "Day-five garden follow state is not enabled on another day.")

	var luca := level.get_node_or_null("Luca") as LucaPlayer
	test.expect(luca != null, "Garden contains the frame-animated Luca character.")
	if luca != null:
		var luca_sprite := luca.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		test.expect(luca_sprite != null and luca_sprite.sprite_frames != null, "Garden Luca uses the shared SpriteFrames presentation.")
		if luca_sprite != null and luca_sprite.sprite_frames != null:
			test.expect(luca_sprite.sprite_frames.has_animation(&"idle"), "Garden Luca has the frame-based idle animation.")
			test.expect(luca_sprite.sprite_frames.has_animation(&"run_loop"), "Garden Luca has the frame-based run animation.")
	var luca_follow := level.get_node_or_null("LucaFollow") as VespervaleLucaFollow
	test.expect(luca_follow != null, "Garden has a sewer-style Luca follow controller.")
	if luca_follow != null:
		test.expect_equal(luca_follow.player_path, NodePath("../Player"), "Luca follow targets Sherry.")
		test.expect_equal(luca_follow.luca_path, NodePath("../Luca"), "Luca follow drives the frame-animated Luca node.")

	var dialogue_source := FileAccess.get_file_as_string("res://day/levels/Vespervale/vespervale_day_five_intro.dialogue")
	test.expect(dialogue_source.contains("~ start") and dialogue_source.contains("~ bridge"), "Day-five dialogue has staged start and bridge titles.")
	test.expect(dialogue_source.contains("你没有必要看见吾") and dialogue_source.contains("主线任务：未醒之谷"), "Day-five dialogue contains the illusion reveal and task update.")
	test.expect(dialogue_source.contains("vespervale_luca_pull") and dialogue_source.contains("vespervale_serena_dissolve"), "Day-five dialogue drives Luca's rescue and Serena's dissolve.")

	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree != null:
		scene_tree.root.add_child(level)
		day_five_intro._play_luca_pull()
		test.expect(luca.visible, "The rescue beat reveals the frame-animated Luca character.")
		day_five_intro._finish_event()
		test.expect(luca_follow.is_follow_enabled(), "Finishing the story hands Luca over to the follow controller.")
		player.global_position = Vector2(900.0, 500.0)
		luca.global_position = Vector2(300.0, 500.0)
		luca_follow._physics_process(1.0 / 60.0)
		test.expect(float(luca.get("_external_direction")) > 0.0, "Luca runs toward Sherry when she moves beyond the follow distance.")

	level.free()

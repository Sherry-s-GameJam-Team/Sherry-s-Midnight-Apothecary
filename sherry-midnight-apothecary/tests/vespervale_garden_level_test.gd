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

	level.free()

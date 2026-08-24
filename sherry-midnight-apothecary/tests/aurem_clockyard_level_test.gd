extends RefCounted

const AUREM_SCRIPT := preload("res://day/levels/Aurem Clockyard/aurem_clockyard.gd")


static func run(test: TestSupport) -> void:
	var level_data := load("res://day/levels/Aurem Clockyard/aurem_clockyard_level.tres") as LevelData
	test.expect(level_data != null, "Aurem Clockyard LevelData resource can be loaded.")
	if level_data != null:
		test.expect_equal(level_data.id, &"aurem_clockyard", "LevelData id is aurem_clockyard.")
		test.expect(level_data.content_scene != null, "LevelData content_scene is assigned.")
		test.expect_equal(level_data.default_entry_id, &"default", "Default entry id is default.")
		test.expect(level_data.display_name.length() > 0, "Display name is configured.")
		test.expect(level_data.disaster_name.length() > 0, "Disaster name is configured.")

	var packed := load("res://day/levels/Aurem Clockyard/aurem_clockyard.tscn") as PackedScene
	test.expect(packed != null, "Aurem Clockyard scene can be loaded.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	test.expect(level != null, "Aurem Clockyard scene instantiates.")
	if level == null:
		return

	var player: CharacterBody2D = level.get_node_or_null("Player") as CharacterBody2D
	test.expect(player != null, "Aurem Clockyard contains Player.")
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
		test.expect(entry_points.has_node("farm"), "farm entry exists.")
		test.expect(entry_points.has_node("tower"), "tower entry exists.")
		test.expect(entry_points.has_node("tower_inner"), "tower_inner entry exists.")

	var farm_normal: CanvasItem = level.get_node_or_null("Background/CS/Farm/FarmNormal") as CanvasItem
	if farm_normal == null:
		farm_normal = level.get_node_or_null("World/Farm/FarmNormal") as CanvasItem
	var farm_corrupted: CanvasItem = level.get_node_or_null("Background/CS/Farm/FarmCorrupted") as CanvasItem
	if farm_corrupted == null:
		farm_corrupted = level.get_node_or_null("World/Farm/FarmCorrupted") as CanvasItem
	test.expect(farm_normal != null and farm_corrupted != null, "Farm visuals exist under CS layer.")

	var fs: Parallax2D = level.get_node_or_null("Background/FS") as Parallax2D
	var ms: Parallax2D = level.get_node_or_null("Background/MS") as Parallax2D
	var cs: Parallax2D = level.get_node_or_null("Background/CS") as Parallax2D
	test.expect(fs != null and ms != null and cs != null, "Parallax background layers (FS, MS, CS) are configured.")
	if cs != null:
		test.expect_equal(cs.scroll_scale, Vector2(1, 1), "CS layer scroll_scale is (1, 1) as baseline.")
		test.expect_equal(cs.repeat_size, Vector2.ZERO, "CS layer repeat_size is ZERO (no scroll repetition).")
	if fs != null and ms != null:
		test.expect_equal(fs.repeat_size, Vector2.ZERO, "FS layer repeat_size is ZERO.")
		test.expect_equal(ms.repeat_size, Vector2.ZERO, "MS layer repeat_size is ZERO.")
		test.expect_equal(fs.scroll_scale.y, 0.0, "FS layer vertical scroll_scale is 0 for bottom lock.")
		test.expect_equal(ms.scroll_scale.y, 0.0, "MS layer vertical scroll_scale is 0 for bottom lock.")

	var tower: Node = level.get_node_or_null("Background/CS/Tower/GreatTower")
	if tower == null:
		tower = level.get_node_or_null("World/Tower/GreatTower")
	var tower_inner: Node = level.get_node_or_null("Background/CS/Tower/TowerInner")
	if tower_inner == null:
		tower_inner = level.get_node_or_null("World/Tower/TowerInner")
	test.expect(tower != null and tower_inner != null, "Tower exterior and inner visuals are deployed under CS layer.")

	var entrance_portal: Node = level.get_node_or_null("World/Portals/EntrancePortal")
	var tower_portal: Node = level.get_node_or_null("World/Portals/TowerPortal")
	test.expect(entrance_portal != null and tower_portal != null, "Door portals are deployed.")

	var npc: Node = level.get_node_or_null("World/NPCs/Clockmaker")
	test.expect(npc != null, "Clockmaker NPC is deployed.")

	var daily_npcs: Node = level.get_node_or_null("World/NPCs/DailyNPCs")
	test.expect(daily_npcs != null, "DailyNPCs container is deployed.")
	if daily_npcs != null:
		test.expect(daily_npcs.has_node("NPC_Otto"), "NPC_Otto exists.")
		test.expect(daily_npcs.has_node("NPC_Elena"), "NPC_Elena exists.")
		test.expect(daily_npcs.has_node("NPC_Timmy"), "NPC_Timmy exists.")
		test.expect(daily_npcs.has_node("NPC_Fiona"), "NPC_Fiona exists.")
		test.expect(daily_npcs.has_node("NPC_Bard"), "NPC_Bard exists.")

	var ground_node: StaticBody2D = level.get_node_or_null("WorldBounds/Ground") as StaticBody2D
	test.expect(ground_node != null, "WorldBounds/Ground exists.")
	if ground_node != null:
		test.expect_equal(int(ground_node.collision_layer), 1, "WorldBounds/Ground has collision_layer = 1.")

	# Test corruption state toggles
	level.call("set_corrupted", true)
	test.expect(farm_corrupted.visible, "Farm corrupted sprite is visible in corrupted state.")
	test.expect(not farm_normal.visible, "Farm normal sprite is hidden in corrupted state.")
	if daily_npcs != null:
		test.expect(not daily_npcs.visible, "Daily NPCs are hidden in corrupted state.")
	if npc != null:
		test.expect(npc.visible, "Clockmaker is visible in corrupted state.")

	level.call("set_farm_cleansed", true)
	test.expect(farm_normal.visible, "Farm normal sprite is visible after cleansing.")
	test.expect(not farm_corrupted.visible, "Farm corrupted sprite is hidden after cleansing.")
	if daily_npcs != null:
		test.expect(daily_npcs.visible, "Daily NPCs are visible in normal/cleansed state.")
	if npc != null:
		test.expect(not npc.visible, "Clockmaker disappears in normal/cleansed state.")

	level.free()

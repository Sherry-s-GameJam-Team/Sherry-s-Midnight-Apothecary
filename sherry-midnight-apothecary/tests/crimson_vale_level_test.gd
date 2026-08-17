extends RefCounted

const CRIMSON_VALE_SCRIPT := preload("res://day/levels/Crimson Vale/crimson_vale.gd")


static func run(test: TestSupport) -> void:
	var level_data := load("res://day/levels/Crimson Vale/crimson_vale_level.tres") as LevelData
	test.expect(level_data != null, "Crimson Vale LevelData resource can be loaded.")
	if level_data != null:
		test.expect_equal(level_data.id, &"crimson_vale", "LevelData id is crimson_vale.")
		test.expect(level_data.content_scene != null, "LevelData content_scene is assigned.")
		test.expect_equal(level_data.default_entry_id, &"default", "Default entry id is default.")
		test.expect(level_data.display_name.length() > 0, "Display name is configured.")
		test.expect(level_data.disaster_name.length() > 0, "Disaster name is configured.")

	var packed := load("res://day/levels/Crimson Vale/crimson_vale.tscn") as PackedScene
	test.expect(packed != null, "Crimson Vale scene can be loaded.")
	if packed == null:
		return

	var level: Node = packed.instantiate()
	test.expect(level != null, "Crimson Vale scene instantiates.")
	if level == null:
		return

	var player: CharacterBody2D = level.get_node_or_null("Player") as CharacterBody2D
	test.expect(player != null, "Crimson Vale contains Player.")
	if player != null:
		test.expect(player.has_node("SherryCollision"), "Player has SherryCollision.")
		test.expect(player.has_node("SherryPresentation"), "Player has SherryPresentation.")
		test.expect(player.has_node("PotionThrower"), "Player has PotionThrower.")
		test.expect(player.has_node("Camera2D"), "Player has Camera2D.")

	var entry_points: Node = level.get_node_or_null("EntryPoints")
	test.expect(entry_points != null, "EntryPoints node exists.")
	if entry_points != null:
		test.expect(entry_points.has_node("default"), "default entry exists.")
		test.expect(entry_points.has_node("from_home"), "from_home entry exists.")
		test.expect(entry_points.has_node("from_village"), "from_village entry exists.")
		test.expect(entry_points.has_node("gate"), "gate entry exists.")

	var gate_broken: CanvasItem = level.get_node_or_null("World/DanxinGate/GateBroken") as CanvasItem
	var gate_restored: CanvasItem = level.get_node_or_null("World/DanxinGate/GateRestored") as CanvasItem
	test.expect(gate_broken != null and gate_restored != null, "Danxin Gate visuals exist.")

	var fs: Parallax2D = level.get_node_or_null("Background/FS") as Parallax2D
	var ms: Parallax2D = level.get_node_or_null("Background/MS") as Parallax2D
	var cs: Parallax2D = level.get_node_or_null("Background/CS") as Parallax2D
	test.expect(fs != null and ms != null and cs != null, "Parallax background layers (FS, MS, CS) are configured.")

	var house: Node = level.get_node_or_null("World/Village/House")
	var shop: Node = level.get_node_or_null("World/Village/Shop")
	var rack: Node = level.get_node_or_null("World/Village/MapleRack")
	var chime: Node = level.get_node_or_null("World/Village/WindChime")
	test.expect(house != null and shop != null and rack != null and chime != null, "Village buildings and props are deployed.")

	# State testing
	level.call("set_corrupted", true)
	test.expect(gate_broken.visible, "Broken gate is visible in corrupted state.")
	test.expect(not gate_restored.visible, "Restored gate is hidden in corrupted state.")

	level.call("set_gate_repaired", true)
	test.expect(gate_restored.visible, "Restored gate is visible after repair.")
	test.expect(not gate_broken.visible, "Broken gate is hidden after repair.")

	level.free()

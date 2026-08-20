extends RefCounted


static func run(test: TestSupport) -> void:
	var level_data := load("res://day/levels/crownland/crownland_level.tres") as LevelData
	test.expect(level_data != null, "Crownland LevelData resource can be loaded.")
	if level_data != null:
		test.expect_equal(level_data.id, &"crownland", "LevelData id is crownland.")
		test.expect(level_data.content_scene != null, "LevelData content_scene is assigned.")

	var packed := load("res://day/levels/crownland/crownland.tscn") as PackedScene
	test.expect(packed != null, "Crownland scene can be loaded.")
	if packed == null:
		return

	var level := packed.instantiate() as CrownlandLevel
	test.expect(level != null, "Crownland scene instantiates.")
	if level == null:
		return

	test.expect(level.get_node_or_null("Background/FS") is Parallax2D, "FS parallax layer exists.")
	test.expect(level.get_node_or_null("Background/MS") is Parallax2D, "MS parallax layer exists.")
	test.expect(level.get_node_or_null("Background/CS") is Parallax2D, "CS parallax layer exists.")
	test.expect(level.get_node_or_null("Player/SherryCollision") != null, "Player has SherryCollision.")
	test.expect(level.get_node_or_null("Player/SherryPresentation") != null, "Player has SherryPresentation.")
	test.expect(level.get_node_or_null("Player/PotionThrower") != null, "Player has PotionThrower.")
	test.expect(level.get_node_or_null("DebugUI/DeveloperConsole") != null, "Standalone DeveloperConsole is deployed.")
	test.expect(level.get_node_or_null("PauseMenuLayer/PauseMenu") != null, "Standalone PauseMenu is deployed.")
	test.expect(level.get_node_or_null("EntryPoints/default") != null, "default entry exists.")
	test.expect(level.get_node_or_null("EntryPoints/palace") != null, "palace entry exists.")

	level.call("set_corrupted", true)
	test.expect((level.get_node("Background/FS/CorruptedSky") as CanvasItem).visible, "Corrupted sky is visible in corrupted state.")
	test.expect(not (level.get_node("Background/CS/City") as CanvasItem).visible, "Normal city is hidden in corrupted state.")
	level.free()

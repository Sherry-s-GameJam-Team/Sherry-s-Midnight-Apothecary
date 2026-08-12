extends RefCounted


static func run(test: TestSupport) -> void:
	var packed := load("res://tests/dual_world/dual_world_puzzle_demo.tscn") as PackedScene
	test.expect(packed != null, "Dual-world whitebox scene loads.")
	if packed == null:
		return
	var level := packed.instantiate()
	for required_path: String in [
		"SharedWorld/Background",
		"SharedWorld/SharedVisual",
		"SharedWorld/SharedCollision",
		"SharedWorld/SharedInteractables",
		"CorruptedWorld/Visual",
		"CorruptedWorld/Collision",
		"CorruptedWorld/WorldObjects",
		"OriginalWorld/Visual",
		"OriginalWorld/Collision",
		"OriginalWorld/WorldObjects",
		"Actors/Sherry",
		"Actors/Luca",
		"Systems/DualWorldManager",
		"Systems/DualProtagonistController",
		"Systems/DualWorldState",
	]:
		test.expect(level.has_node(required_path), "Dual-world level contains %s." % required_path)
	for marker_name: String in ["Origin", "LevelStart", "GroundBase", "PuzzleAnchor01", "PuzzleAnchor02", "LevelEnd"]:
		test.expect(level.has_node("AlignmentMarkers/%s" % marker_name), "Dual-world level contains %s alignment marker." % marker_name)
	test.expect(level.find_children("*", "TileMap", true, false).is_empty(), "Dual-world scene contains no TileMap nodes.")
	test.expect(level.find_children("*", "TileMapLayer", true, false).is_empty(), "Dual-world scene contains no TileMapLayer nodes.")
	level.free()

	var tower_packed := load("res://tests/dual_world_tree_tower/tree_tower_demo.tscn") as PackedScene
	test.expect(tower_packed != null, "Dual-world Giant Tree Tower scene loads.")
	if tower_packed == null:
		return
	var tower := tower_packed.instantiate()
	for required_path: String in [
		"SharedWorld/SharedCollision/RemotePlatformA",
		"SharedWorld/SharedCollision/RemotePlatformB",
		"SharedWorld/SharedCollision/RemotePlatformC",
		"CorruptedWorld/WorldObjects/RootStep1",
		"CorruptedWorld/WorldObjects/SapStep1",
		"CorruptedWorld/WorldObjects/RottenBarrier",
		"OriginalWorld/Visual/ControlRoomGlow",
		"Actors/Sherry",
		"Actors/Luca",
		"Systems/DualWorldManager",
		"Systems/DualProtagonistController",
		"Systems/DualWorldState",
	]:
		test.expect(tower.has_node(required_path), "Tree Tower contains %s." % required_path)
	test.expect(tower.find_children("*", "TileMap", true, false).is_empty(), "Tree Tower contains no TileMap nodes.")
	test.expect(tower.find_children("*", "TileMapLayer", true, false).is_empty(), "Tree Tower contains no TileMapLayer nodes.")
	tower.free()

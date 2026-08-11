extends RefCounted


static func run(test: TestSupport) -> void:
	var packed := load("res://day/levels/_tests/dual_world/dual_world_puzzle_demo.tscn") as PackedScene
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


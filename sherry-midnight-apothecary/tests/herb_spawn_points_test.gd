extends RefCounted

const GRASSLAND_SCENE := preload("res://day/levels/grassland/grass.tscn")
const FOREST_SCENE := preload("res://day/levels/forest/forest.tscn")

const GRASSLAND_IDS: Array[StringName] = [
	&"herdsmans_loaf_bush", &"stardust_puffy_lion", &"grail_lily", &"dew_flask_herb", &"old_mans_noose",
	&"praise_star_maple", &"herdsmans_loaf_bush", &"stardust_puffy_lion", &"grail_lily", &"dew_flask_herb",
]
const FOREST_IDS: Array[StringName] = [&"stardust_puffy_lion", &"grail_lily", &"dew_flask_herb", &"old_mans_noose"]


static func run(test: TestSupport) -> void:
	_assert_fixed_points(test, GRASSLAND_SCENE, NodePath("HerbSpawns"), GRASSLAND_IDS, "Grassland")
	_assert_fixed_points(test, FOREST_SCENE, NodePath("Exterior/HerbSpawns"), FOREST_IDS, "Forest")


static func _assert_fixed_points(test: TestSupport, scene: PackedScene, points_path: NodePath, expected_ids: Array[StringName], label: String) -> void:
	var level := scene.instantiate()
	var container := level.get_node_or_null(points_path) as Node2D
	test.expect(container != null, "%s exposes its authored herb spawn container." % label)
	if container == null:
		level.free()
		return
	var points := container.get_children()
	test.expect_equal(points.size(), expected_ids.size(), "%s has the expected number of fixed herb points." % label)
	for index: int in mini(points.size(), expected_ids.size()):
		var point := points[index] as HerbSpawnPoint
		test.expect(point != null, "%s point %d is a HerbSpawnPoint." % [label, index + 1])
		if point == null:
			continue
		test.expect(point.herb_scene != null, "%s point %s has an explicitly assigned plant scene." % [label, point.name])
		if point.herb_scene == null:
			continue
		var herb := point.herb_scene.instantiate() as HerbInteractable
		test.expect(herb != null, "%s point %s uses a HerbInteractable scene." % [label, point.name])
		if herb != null:
			test.expect_equal(herb.ingredient_id, expected_ids[index], "%s point %s has a fixed ingredient ID." % [label, point.name])
			herb.free()
	level.free()

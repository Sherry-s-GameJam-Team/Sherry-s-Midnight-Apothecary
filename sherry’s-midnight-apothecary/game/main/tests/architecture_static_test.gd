extends SceneTree

const LEVEL_DEFINITIONS := {
	&"town": "res://game/main/data/levels/town_level.tres",
	&"raintree": "res://game/main/data/levels/raintree_level.tres",
	&"lake": "res://game/main/data/levels/lake_level.tres",
}
const LEVEL_SCENES := [
	"res://game/main/scenes/town/town_morning.tscn",
	"res://game/main/scenes/raintree/raintree.tscn",
	"res://game/main/scenes/lake/lake.tscn",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var seen_ids: Dictionary = {}
	for level_id in LEVEL_DEFINITIONS:
		var definition := load(LEVEL_DEFINITIONS[level_id]) as LevelDefinition
		if definition == null:
			failures.append("cannot load LevelDefinition %s" % level_id)
			continue
		if definition.level_id != level_id:
			failures.append("definition id mismatch for %s" % level_id)
		if seen_ids.has(definition.level_id):
			failures.append("duplicate level_id %s" % definition.level_id)
		seen_ids[definition.level_id] = true
		if definition.scene == null:
			failures.append("definition %s has empty PackedScene" % level_id)
		elif not FileAccess.file_exists(definition.scene.resource_path):
			failures.append("definition %s points to missing scene" % level_id)

	for scene_path in LEVEL_SCENES:
		var scene := load(scene_path) as PackedScene
		if scene == null:
			failures.append("cannot load scene %s" % scene_path)
			continue
		var instance := scene.instantiate()
		root.add_child(instance)
		var controller := instance.get_node_or_null("LevelController") as LevelController
		if controller == null:
			failures.append("%s missing LevelController" % scene_path)
		else:
			if controller.definition == null:
				failures.append("%s LevelController has no definition" % scene_path)
			if controller.get_spawn() == null:
				failures.append("%s missing default spawn" % scene_path)
			if controller.get_camera_bounds() == null:
				failures.append("%s missing camera bounds" % scene_path)
		if _find_nodes(instance, "Player").size() != 1:
			failures.append("%s must contain exactly one Player" % scene_path)
		var main_camera := instance.get_node_or_null("Player/Camera2D") as Camera2D
		if main_camera == null or not main_camera.enabled:
			failures.append("%s has no enabled player camera" % scene_path)
		if scene_path.ends_with("lake.tscn") and instance.get_node_or_null("LakeWater/ReflectionViewport/ReflectionCamera") == null:
			failures.append("Lake ReflectionCamera missing")
		instance.queue_free()

	if failures.is_empty():
		print("architecture_static_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _find_nodes(node: Node, target_name: String) -> Array[Node]:
	var result: Array[Node] = []
	if node.name == target_name:
		result.append(node)
	for child in node.get_children():
		result.append_array(_find_nodes(child, target_name))
	return result

extends SceneTree

const CASES := {
	"town": "res://game/main/scenes/town/town_morning.tscn",
	"raintree": "res://game/main/scenes/raintree/raintree.tscn",
	"lake": "res://game/main/scenes/lake/lake.tscn",
}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	for level_id in CASES:
		var instance := (load(CASES[level_id]) as PackedScene).instantiate()
		root.add_child(instance)
		var controller := instance.get_node_or_null("LevelController") as LevelController
		if controller == null:
			failures.append("%s has no typed LevelController" % level_id)
		else:
			if controller.level_id != StringName(level_id):
				failures.append("%s has wrong level_id" % level_id)
			if controller.get_player() == null:
				failures.append("%s player contract unresolved" % level_id)
			if controller.get_player_spawn() == null:
				failures.append("%s player_spawn contract unresolved" % level_id)
			if controller.get_camera_bounds() == null:
				failures.append("%s camera_bounds contract unresolved" % level_id)
		var players := _nodes_named(instance, "Player")
		if players.size() != 1:
			failures.append("%s has %d Player nodes" % [level_id, players.size()])
		var player_camera := instance.get_node_or_null("Player/Camera2D") as Camera2D
		if player_camera == null:
			failures.append("%s has no Player/Camera2D" % level_id)
		elif not player_camera.enabled:
			failures.append("%s player camera is not enabled" % level_id)
		instance.queue_free()

	if failures.is_empty():
		print("level_contract_test: PASS")
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	quit(0)

func _nodes_named(node: Node, target_name: String) -> Array[Node]:
	var result: Array[Node] = []
	if node.name == target_name:
		result.append(node)
	for child in node.get_children():
		result.append_array(_nodes_named(child, target_name))
	return result

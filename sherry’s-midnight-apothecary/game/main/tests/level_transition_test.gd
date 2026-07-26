extends SceneTree

const TRANSITION_TIMEOUT := 3.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var game_root := (load("res://game/main/scenes/game_root.tscn") as PackedScene).instantiate()
	root.add_child(game_root)
	await process_frame
	await _wait_until_ready(game_root)
	if game_root.current_scene_key != "town":
		failures.append("initial scene is not town")
	for target in ["raintree", "lake", "town"]:
		var old_scene := game_root.current_scene
		game_root.request_level_change(StringName(target), &"default", {})
		var completed := await _wait_for_scene(game_root, target)
		if not completed:
			failures.append("transition to %s timed out" % target)
		if game_root.is_switching:
			failures.append("is_switching remained true after %s" % target)
		if game_root.current_scene == old_scene:
			failures.append("old scene was not replaced for %s" % target)
		if game_root.current_scene == null or game_root.current_scene.get_node_or_null("Player") == null:
			failures.append("target %s has no player" % target)
		var duplicate_request := game_root.request_level_change(StringName(target), &"default", {})
		if duplicate_request:
			failures.append("duplicate request was accepted for %s" % target)

	if failures.is_empty():
		print("level_transition_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

func _wait_until_ready(game_root: Node) -> void:
	var elapsed := 0.0
	while game_root.current_scene == null and elapsed < TRANSITION_TIMEOUT:
		await process_frame
		elapsed += 0.016

func _wait_for_scene(game_root: Node, target: String) -> bool:
	var elapsed := 0.0
	while elapsed < TRANSITION_TIMEOUT:
		if game_root.current_scene_key == target and not game_root.is_switching:
			return true
		await process_frame
		elapsed += 0.016
	return false

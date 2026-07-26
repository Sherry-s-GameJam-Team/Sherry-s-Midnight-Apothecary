extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_root := (load("res://game/main/scenes/game_root.tscn") as PackedScene).instantiate()
	root.add_child(game_root)
	await process_frame
	var failures: Array[String] = []
	if game_root.current_scene_key != "town":
		failures.append("initial scene is not town")
	game_root.transition_to_destination("raintree")
	await create_timer(1.5).timeout
	if game_root.current_scene_key != "raintree":
		failures.append("town -> raintree did not complete")
	game_root.transition_to_destination("lake")
	await create_timer(1.5).timeout
	if game_root.current_scene_key != "lake":
		failures.append("raintree -> lake did not complete")
	game_root.transition_to_destination("town")
	await create_timer(1.5).timeout
	if game_root.current_scene_key != "town":
		failures.append("lake -> town did not complete")
	var router := game_root.get_node_or_null("SceneRouter") as SceneRouter
	if router == null:
		failures.append("GameRoot missing SceneRouter")
	elif router.is_changing:
		failures.append("SceneRouter remained locked after transition")
	if failures.is_empty():
		print("scene_transition_test: PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)

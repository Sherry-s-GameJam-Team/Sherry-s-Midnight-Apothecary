extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if ForestCrownLevel.completion_return_level_id() != &"forest":
		_fail("Forest Crown completion must return to Forest/from_crown for the Enzuo resolution sequence")
	if ForestInteriorLevel.is_home_route_unlocked(false):
		_fail("Forest Interior home route must remain inactive before the crown boss is purified")
	if not ForestInteriorLevel.is_home_route_unlocked(true):
		_fail("Forest Interior home route must unlock after the crown boss is purified")

	# 1. Verify forest_interior has DeveloperConsole, PauseMenu, and ExitToCrown
	var interior_packed := load("res://day/levels/forest/interior/forest_interior.tscn") as PackedScene
	if interior_packed == null:
		_fail("Could not load forest_interior.tscn")
		_finish()
		return

	var interior := interior_packed.instantiate() as ForestInteriorLevel
	root.add_child(interior)
	await process_frame
	await process_frame

	if interior.get_node_or_null("DebugUI/DeveloperConsole") == null:
		_fail("forest_interior missing DebugUI/DeveloperConsole")
	if interior.get_node_or_null("PauseMenuLayer/PauseMenu") == null:
		_fail("forest_interior missing PauseMenuLayer/PauseMenu")
	var home_door := interior.get_node_or_null("HomeDoor") as DoorPortal
	if home_door == null:
		_fail("forest_interior missing HomeDoor")
	elif home_door.required_tutorial_flag != &"forest_completed":
		_fail("HomeDoor must require forest_completed before it can return home")

	var exit := interior.get_node_or_null("ExitToCrown") as Area2D
	if exit == null:
		_fail("forest_interior missing ExitToCrown Area2D")
	else:
		var exit_col := exit.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if exit_col == null or exit_col.position != Vector2.ZERO:
			_fail("ExitToCrown CollisionShape2D should be centered at (0, 0)")

	# Check EntryPoints has from_crown and down markers pointing to bottom
	var from_crown := interior.get_node_or_null("EntryPoints/from_crown") as Marker2D
	var down_marker := interior.get_node_or_null("EntryPoints/down") as Marker2D
	if from_crown == null or from_crown.position.y < 0:
		_fail("EntryPoints/from_crown should point to bottom platform (Y > 0)")
	if down_marker == null:
		_fail("EntryPoints/down is missing")

	interior.queue_free()
	await process_frame

	# 2. Verify forest_crown has DeveloperConsole, PauseMenu, and ExitPortal with DirectLift texture
	var crown_packed := load("res://day/levels/forest/crown/forest_crown.tscn") as PackedScene
	if crown_packed == null:
		_fail("Could not load forest_crown.tscn")
		_finish()
		return

	var crown := crown_packed.instantiate() as ForestCrownLevel
	root.add_child(crown)
	await process_frame
	await process_frame

	if crown.get_node_or_null("DebugUI/DeveloperConsole") == null:
		_fail("forest_crown missing DebugUI/DeveloperConsole")
	if crown.get_node_or_null("PauseMenuLayer/PauseMenu") == null:
		_fail("forest_crown missing PauseMenuLayer/PauseMenu")

	var portal := crown.get_node_or_null("ExitPortal") as Area2D
	if portal == null:
		_fail("forest_crown missing ExitPortal")
	else:
		var sprite := portal.get_node_or_null("Sprite2D") as Sprite2D
		if sprite == null or sprite.texture == null:
			_fail("ExitPortal DirectLift missing Sprite2D texture")

	crown.queue_free()
	await process_frame

	_finish()

func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)

func _finish() -> void:
	if failures.is_empty():
		print("FOREST_INTERIOR_TO_CROWN_TEST: PASS")
		quit(0)
	else:
		print("FOREST_INTERIOR_TO_CROWN_TEST: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)

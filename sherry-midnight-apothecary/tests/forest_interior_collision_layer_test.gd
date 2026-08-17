extends SceneTree

const SCENE_PATH := "res://day/levels/forest/interior/forest_interior.tscn"

const REALITY_LAYER_MASK := 3 # Layers 1 and 2
const LUCA_WORLD_LAYER := 4   # Layer 3 (1 << 2)

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Unable to load %s" % SCENE_PATH)
		_finish()
		return
	var level := packed.instantiate() as ForestInteriorLevel
	root.add_child(level)
	await process_frame

	var player: CharacterBody2D = level.player
	var luca: CharacterBody2D = level.luca

	if player == null or luca == null:
		_fail("Player or Luca node is missing")
		_finish()
		return

	# 1. Test Sherry's collision mask: Must have Reality layers (1, 2) and MUST NOT have LucaWorld layer (4)
	if (player.collision_mask & 1) == 0:
		_fail("Player (Sherry) collision_mask must include Reality solid layer 1")
	if (player.collision_mask & 2) == 0:
		_fail("Player (Sherry) collision_mask must include Reality one-way layer 2")
	if (player.collision_mask & LUCA_WORLD_LAYER) != 0:
		_fail("Player (Sherry) collision_mask MUST NOT include LucaWorld layer 4 (spirit plane)")

	# 2. Test Luca's collision mask: Must have Reality layers (1, 2) AND LucaWorld layer (4)
	if (luca.collision_mask & 1) == 0:
		_fail("Luca collision_mask must include Reality solid layer 1")
	if (luca.collision_mask & 2) == 0:
		_fail("Luca collision_mask must include Reality one-way layer 2")
	if (luca.collision_mask & LUCA_WORLD_LAYER) == 0:
		_fail("Luca collision_mask must include LucaWorld layer 4")

	# 3. Test RealityWorld platforms: All must be usable by both Sherry and Luca
	var reality := level.get_node_or_null("RealityWorld")
	if reality != null:
		var reality_platforms := _find_physics_bodies_recursive(reality)
		if reality_platforms.is_empty():
			_fail("RealityWorld has no platforms")
		for body in reality_platforms:
			# Platform layer must be within Reality (1 or 2 or 3)
			if (body.collision_layer & REALITY_LAYER_MASK) == 0:
				_fail("RealityWorld platform '%s' collision_layer (%d) is not on Reality layers (1 or 2)" % [body.name, body.collision_layer])
			# Sherry must collide with it
			if (player.collision_mask & body.collision_layer) == 0:
				_fail("Player (Sherry) cannot collide with RealityWorld platform '%s'" % body.name)
			# Luca must collide with it
			if (luca.collision_mask & body.collision_layer) == 0:
				_fail("Luca cannot collide with RealityWorld platform '%s'" % body.name)

	# 4. Test LucaWorldOnly platforms: All must be exclusive to Luca (layer 4)
	var luca_world := level.get_node_or_null("LucaWorldOnly")
	if luca_world != null:
		var luca_platforms := _find_physics_bodies_recursive(luca_world)
		if luca_platforms.is_empty():
			_fail("LucaWorldOnly has no platforms")
		for body in luca_platforms:
			if body.collision_layer != LUCA_WORLD_LAYER:
				_fail("LucaWorldOnly platform '%s' collision_layer is %d, expected %d" % [body.name, body.collision_layer, LUCA_WORLD_LAYER])
			# Sherry must NOT collide with it (passes through)
			if (player.collision_mask & body.collision_layer) != 0:
				_fail("Player (Sherry) MUST NOT collide with LucaWorldOnly platform '%s'" % body.name)
			# Luca MUST collide with it
			if (luca.collision_mask & body.collision_layer) == 0:
				_fail("Luca must collide with LucaWorldOnly platform '%s'" % body.name)

	level.queue_free()
	await process_frame
	_finish()

func _find_physics_bodies_recursive(node: Node) -> Array[PhysicsBody2D]:
	var result: Array[PhysicsBody2D] = []
	for child in node.get_children():
		if child is StaticBody2D or child is AnimatableBody2D:
			result.append(child as PhysicsBody2D)
		result.append_array(_find_physics_bodies_recursive(child))
	return result

func _fail(msg: String) -> void:
	failures.append(msg)
	push_error(msg)

func _finish() -> void:
	if failures.is_empty():
		print("FOREST_INTERIOR_COLLISION_LAYER_TEST: PASS")
		quit(0)
	else:
		print("FOREST_INTERIOR_COLLISION_LAYER_TEST: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)

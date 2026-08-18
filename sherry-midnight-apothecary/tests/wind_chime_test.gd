class_name WindChimeTest
extends RefCounted

const CHIME_SCENE_PATH := "res://day/levels/Crimson Vale/props/wind_chime.tscn"
const WindChimeScript := preload("res://day/levels/Crimson Vale/props/wind_chime.gd")

var _tree_root: Node


func run(tree_root: Node = null) -> void:
	_tree_root = tree_root
	print("Starting WindChime unit tests...")
	_test_scene_structure_and_nodes()
	_test_pendulum_physics_and_damping()
	_test_individual_part_impulse_and_breeze()
	_test_player_collision_and_push()
	_test_wind_and_explosion_effects()
	print("All WindChime unit tests passed successfully!")


func _create_root() -> Node2D:
	var node := Node2D.new()
	if _tree_root != null:
		_tree_root.add_child(node)
	return node


func _cleanup_root(node: Node2D) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()


func _test_scene_structure_and_nodes() -> void:
	var scene: PackedScene = load(CHIME_SCENE_PATH)
	assert(scene != null, "WindChime scene should load from %s" % CHIME_SCENE_PATH)

	var chime: Node2D = scene.instantiate() as Node2D
	assert(chime is WindChimeScript, "Root must be WindChime")

	var bg_frame := chime.get_node_or_null("BackgroundFrame") as Sprite2D
	var chimes_container := chime.get_node_or_null("Chimes") as Node2D

	assert(bg_frame != null, "BackgroundFrame Sprite2D must exist")
	assert(bg_frame.texture != null, "BackgroundFrame must have a texture (风铃.png)")
	assert(chimes_container != null, "Chimes container must exist")

	var expected_ids := ["p1", "p2", "p3", "p4", "p5", "p6", "p7"]
	for id in expected_ids:
		var part_node := chimes_container.get_node_or_null("Chime_%s" % id) as Node2D
		assert(part_node != null, "Part Chime_%s must exist" % id)
		var sprite := part_node.get_node_or_null("Sprite2D") as Sprite2D
		var area := part_node.get_node_or_null("Area2D") as Area2D
		assert(sprite != null, "Part %s must have Sprite2D" % id)
		assert(sprite.texture != null, "Part %s must have texture" % id)
		assert(area != null, "Part %s must have Area2D collision trigger" % id)

	chime.free()


func _test_pendulum_physics_and_damping() -> void:
	var scene: PackedScene = load(CHIME_SCENE_PATH)
	var chime: Node2D = scene.instantiate() as Node2D
	var root := _create_root()
	root.add_child(chime)

	chime.set("enable_ambient_breeze", false) # Isolate impulse

	# Push piece 1 (index 1)
	chime.call("push_chime", 1, 10.0)

	var pieces: Array = chime.get("_pieces")
	assert(not pieces.is_empty(), "Pieces array must be populated")

	var p1: Object = null
	for piece in pieces:
		if piece.get("index") == 1:
			p1 = piece
			break
	assert(p1 != null, "Piece 1 must exist")
	assert(float(p1.get("angular_velocity")) > 0.0, "Angular velocity should be positive after push")

	# Step physics forward: angular velocity should transfer to angle
	chime._physics_process(0.1)
	assert(float(p1.get("angle")) > 0.0, "Angle should become positive")

	# Background frame must remain static (rotation 0)
	var bg_frame := chime.get_node_or_null("BackgroundFrame") as Sprite2D
	assert(is_equal_approx(bg_frame.rotation, 0.0), "Background frame must remain stationary at 0 rotation")

	_cleanup_root(root)


func _test_individual_part_impulse_and_breeze() -> void:
	var scene: PackedScene = load(CHIME_SCENE_PATH)
	var chime: Node2D = scene.instantiate() as Node2D
	var root := _create_root()
	root.add_child(chime)

	var struck_data := { "struck_count": 0, "last_index": 0 }
	chime.connect("chime_struck", func(idx: int, _str: float) -> void:
		struck_data["struck_count"] += 1
		struck_data["last_index"] = idx
	)

	chime.call("push_chime", 4, 6.0)
	assert(struck_data["struck_count"] == 1, "chime_struck signal should be emitted")
	assert(struck_data["last_index"] == 4, "Struck index should be 4")

	_cleanup_root(root)


func _test_player_collision_and_push() -> void:
	var scene: PackedScene = load(CHIME_SCENE_PATH)
	var chime: Node2D = scene.instantiate() as Node2D
	var root := _create_root()
	root.add_child(chime)

	var signal_data := { "player_passed": false }
	chime.connect("player_passed", func(_p: CharacterBody2D) -> void:
		signal_data["player_passed"] = true
	)

	var dummy_player := CharacterBody2D.new()
	dummy_player.name = "Player"
	dummy_player.velocity = Vector2(150.0, 0.0) # Moving right
	root.add_child(dummy_player)

	var pieces: Array = chime.get("_pieces")
	var piece_target: Object = pieces[0]

	# Trigger collision
	chime.call("_on_chime_body_entered", dummy_player, piece_target)
	assert(signal_data["player_passed"], "player_passed signal must be emitted")
	assert(float(piece_target.get("angular_velocity")) > 0.0, "Player moving right should push chime clockwise")

	_cleanup_root(root)


func _test_wind_and_explosion_effects() -> void:
	var scene: PackedScene = load(CHIME_SCENE_PATH)
	var chime: Node2D = scene.instantiate() as Node2D
	var root := _create_root()
	root.add_child(chime)

	var pieces: Array = chime.get("_pieces")

	# Test hit_by_wind
	chime.call("hit_by_wind", Vector2.LEFT, 500.0)
	for piece in pieces:
		assert(float(piece.get("angular_velocity")) < 0.0, "Wind blowing left should impart negative angular velocity")

	# Reset piece velocities
	for piece in pieces:
		piece.set("angular_velocity", 0.0)
		piece.set("angle", 0.0)

	# Test hit_by_explosion on left
	chime.call("hit_by_explosion", chime.global_position + Vector2(-100, 0), 1.0)
	for piece in pieces:
		assert(float(piece.get("angular_velocity")) > 0.0, "Explosion on left should push parts to the right")

	_cleanup_root(root)

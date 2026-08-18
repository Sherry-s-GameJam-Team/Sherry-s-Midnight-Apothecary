class_name BloodLeafSwarmTest
extends RefCounted

const SWARM_SCENE_PATH := "res://day/levels/Crimson Vale/hazards/blood_leaf_swarm.tscn"
const BloodLeafSwarmScript := preload("res://day/levels/Crimson Vale/hazards/blood_leaf_swarm.gd")

var _tree_root: Node


func run(tree_root: Node = null) -> void:
	_tree_root = tree_root
	print("Starting BloodLeafSwarm unit tests...")
	_test_scene_instantiation_and_defaults()
	_test_telegraph_to_tracking_lifecycle()
	_test_continuous_looping_behavior()
	_test_proximity_trigger_behavior()
	_test_delayed_tracking_history()
	_test_wind_potion_interaction()
	_test_explosion_potion_interaction()
	_test_purification_lifecycle()
	_test_potion_effect_and_hit_receivers()
	_test_player_damage_and_knockback()
	_test_normal_attack_damage_and_elimination()
	_test_max_active_swarms_limit()
	print("All BloodLeafSwarm unit tests passed successfully!")


func _create_root() -> Node2D:
	var node := Node2D.new()
	if _tree_root != null:
		_tree_root.add_child(node)
	return node


func _cleanup_root(node: Node2D) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()


func _test_scene_instantiation_and_defaults() -> void:
	var scene: PackedScene = load(SWARM_SCENE_PATH)
	assert(scene != null, "Swarm scene should load from %s" % SWARM_SCENE_PATH)

	var swarm: Node2D = scene.instantiate() as Node2D
	assert(swarm != null, "Instantiated scene must be Node2D")
	assert(swarm is BloodLeafSwarmScript, "Instantiated node must be BloodLeafSwarm")

	# Check default exported values
	assert(is_equal_approx(float(swarm.get("telegraph_time")), 0.7), "Default telegraph_time should be 0.7")
	assert(is_equal_approx(float(swarm.get("attack_duration")), 4.0), "Default attack_duration should be 4.0")
	assert(is_equal_approx(float(swarm.get("tracking_delay")), 0.55), "Default tracking_delay should be 0.55")
	assert(is_equal_approx(float(swarm.get("anchor_speed")), 280.0), "Default anchor_speed should be 280.0")
	assert(is_equal_approx(float(swarm.get("damage")), 1.0), "Default damage should be 1.0")
	assert(is_equal_approx(float(swarm.get("knockback_force")), 180.0), "Default knockback_force should be 180.0")
	assert(is_equal_approx(float(swarm.get("corruption_hp")), 3.0), "Default corruption_hp should be 3.0")
	assert(is_equal_approx(float(swarm.get("core_radius")), 60.0), "Default core_radius should be 60.0")
	assert(bool(swarm.get("loop_attacks")) == true, "loop_attacks should default to true")

	# Check child nodes (foreground & background layers)
	var particles_a := swarm.get_node_or_null("LeafParticlesA") as GPUParticles2D
	var particles_b := swarm.get_node_or_null("LeafParticlesB") as GPUParticles2D
	var particles_a_back := swarm.get_node_or_null("LeafParticlesA_Back") as GPUParticles2D
	var particles_b_back := swarm.get_node_or_null("LeafParticlesB_Back") as GPUParticles2D
	var damage_area := swarm.get_node_or_null("DamageArea") as Area2D
	var telegraph := swarm.get_node_or_null("Telegraph") as Node2D

	assert(particles_a != null, "LeafParticlesA (foreground) must exist")
	assert(particles_b != null, "LeafParticlesB (foreground) must exist")
	assert(particles_a_back != null, "LeafParticlesA_Back (background) must exist")
	assert(particles_b_back != null, "LeafParticlesB_Back (background) must exist")
	assert(damage_area != null, "DamageArea node must exist")
	assert(telegraph != null, "Telegraph node must exist")

	assert(particles_a.texture != null, "LeafParticlesA must have a texture")
	assert(particles_b.texture != null, "LeafParticlesB must have a texture")
	assert(particles_a.z_index > 0, "LeafParticlesA should be on positive foreground z_index")
	assert(particles_b.z_index > 0, "LeafParticlesB should be on positive foreground z_index")
	assert(particles_a_back.z_index < 0, "LeafParticlesA_Back should be on negative background z_index")
	assert(particles_b_back.z_index < 0, "LeafParticlesB_Back should be on negative background z_index")
	assert(not particles_a.local_coords, "Particles A should use global coords (local_coords=false)")
	assert(not particles_b.local_coords, "Particles B should use global coords (local_coords=false)")

	swarm.free()


func _test_telegraph_to_tracking_lifecycle() -> void:
	var scene: PackedScene = load(SWARM_SCENE_PATH)
	var swarm: Node2D = scene.instantiate() as Node2D
	swarm.set("auto_start", false)

	var signal_data := {
		"telegraph_count": 0,
		"attack_count": 0
	}
	swarm.connect("telegraph_started", func() -> void: signal_data["telegraph_count"] += 1)
	swarm.connect("attack_started", func() -> void: signal_data["attack_count"] += 1)

	var root := _create_root()
	root.add_child(swarm)

	var dummy_target := Node2D.new()
	dummy_target.global_position = Vector2(300, 300)
	root.add_child(dummy_target)

	swarm.call("start_attack", dummy_target)
	assert(signal_data["telegraph_count"] == 1, "Telegraph started signal should fire on start_attack")
	assert(int(swarm.get("_current_state")) == 1, "State should be TELEGRAPH (1)")
	var damage_area := swarm.get_node_or_null("DamageArea") as Area2D
	assert(damage_area != null and not damage_area.monitoring, "DamageArea should not be monitoring during telegraph")

	# Step time through telegraph phase
	swarm._physics_process(0.4)
	assert(int(swarm.get("_current_state")) == 1, "Should still be in telegraph at 0.4s")

	swarm._physics_process(0.35)
	assert(int(swarm.get("_current_state")) == 2, "State should transition to TRACKING (2) after telegraph_time")
	assert(signal_data["attack_count"] == 1, "Attack started signal should fire when transitioning to TRACKING")
	assert(damage_area.monitoring, "DamageArea should be active during TRACKING")

	_cleanup_root(root)


func _test_continuous_looping_behavior() -> void:
	var scene: PackedScene = load(SWARM_SCENE_PATH)
	var swarm: Node2D = scene.instantiate() as Node2D
	swarm.set("auto_start", false)
	swarm.set("loop_attacks", true)
	swarm.set("loop_interval", 0.5)
	swarm.set("attack_duration", 1.0)
	swarm.set("telegraph_time", 0.2)

	var root := _create_root()
	root.add_child(swarm)

	var dummy_target := Node2D.new()
	dummy_target.global_position = Vector2(100, 100)
	root.add_child(dummy_target)

	swarm.call("start_attack", dummy_target)
	swarm.call("_enter_tracking_state")
	assert(int(swarm.get("_current_state")) == 2, "State is TRACKING")

	# Step through attack duration
	swarm._physics_process(1.1)
	assert(int(swarm.get("_current_state")) == 4, "State should transition to COOLDOWN (4), NOT vanished")

	# Step through cooldown
	swarm._physics_process(0.6)
	assert(int(swarm.get("_current_state")) == 1, "State should loop back to TELEGRAPH (1) to pursue player again")

	_cleanup_root(root)


func _test_proximity_trigger_behavior() -> void:
	var scene: PackedScene = load(SWARM_SCENE_PATH)
	var swarm: Node2D = scene.instantiate() as Node2D
	swarm.set("auto_start", false)
	swarm.set("proximity_trigger", true)
	swarm.set("detection_radius", 200.0)

	var root := _create_root()
	root.add_child(swarm)
	swarm.global_position = Vector2(0, 0)
	swarm.set("_spawn_origin", Vector2(0, 0))
	swarm.set("_current_anchor_pos", Vector2(0, 0))
	swarm.call("_enter_idle_state")

	var dummy_player := Node2D.new()
	dummy_player.add_to_group("player")
	dummy_player.global_position = Vector2(500, 500) # Far away
	root.add_child(dummy_player)

	swarm._physics_process(0.1)
	assert(int(swarm.get("_current_state")) == 0, "Swarm should be IDLE (0) when player is far away")

	# Player approaches within detection radius
	dummy_player.global_position = Vector2(100, 0)
	swarm._physics_process(0.1)
	assert(int(swarm.get("_current_state")) == 1, "Swarm should wake up and enter TELEGRAPH (1) when player approaches")

	_cleanup_root(root)


func _test_delayed_tracking_history() -> void:
	var scene: PackedScene = load(SWARM_SCENE_PATH)
	var swarm: Node2D = scene.instantiate() as Node2D
	swarm.set("auto_start", false)
	swarm.set("tracking_delay", 0.55)
	var root := _create_root()
	root.add_child(swarm)

	var dummy_target := Node2D.new()
	dummy_target.global_position = Vector2(0, 0)
	root.add_child(dummy_target)

	swarm.call("start_attack", dummy_target)
	swarm.call("_enter_tracking_state")

	var history: Array = swarm.get("_history")
	history.clear()
	history.append({"time": 10.0, "pos": Vector2(100, 100)})
	history.append({"time": 10.5, "pos": Vector2(200, 200)})
	history.append({"time": 11.0, "pos": Vector2(300, 300)})

	var query_pos: Vector2 = swarm.call("_get_delayed_target_position")
	assert(query_pos is Vector2, "Should return a Vector2 position")

	_cleanup_root(root)


func _test_wind_potion_interaction() -> void:
	var scene: PackedScene = load(SWARM_SCENE_PATH)
	var swarm: Node2D = scene.instantiate() as Node2D
	swarm.set("auto_start", false)

	var signal_data := { "wind_blown": false }
	swarm.connect("wind_blown", func(dir: Vector2, str_val: float) -> void:
		signal_data["wind_blown"] = true
	)

	var root := _create_root()
	root.add_child(swarm)

	var initial_anchor: Vector2 = swarm.get("_current_anchor_pos")
	swarm.call("hit_by_wind", Vector2.RIGHT, 500.0, 0.8)

	assert(signal_data["wind_blown"], "Wind signal should be emitted")
	var wind_vel: Vector2 = swarm.get("_wind_velocity")
	assert(wind_vel.x > 0.0, "Wind velocity x should be positive")
	var updated_anchor: Vector2 = swarm.get("_current_anchor_pos")
	assert(updated_anchor.x > initial_anchor.x, "Anchor should be pushed by wind")

	_cleanup_root(root)


func _test_explosion_potion_interaction() -> void:
	var scene: PackedScene = load(SWARM_SCENE_PATH)
	var swarm: Node2D = scene.instantiate() as Node2D
	swarm.set("auto_start", false)

	var signal_data := { "dispersed_duration": 0.0 }
	swarm.connect("dispersed", func(dur: float) -> void:
		signal_data["dispersed_duration"] = dur
	)

	var root := _create_root()
	root.add_child(swarm)

	var dummy_target := Node2D.new()
	root.add_child(dummy_target)

	swarm.call("start_attack", dummy_target)
	swarm.call("_enter_tracking_state")
	var damage_area := swarm.get_node_or_null("DamageArea") as Area2D
	assert(damage_area.monitoring, "DamageArea should be monitoring before explosion")

	swarm.call("hit_by_explosion", swarm.global_position + Vector2(-50, 0), 1.0)
	assert(int(swarm.get("_current_state")) == 3, "State should become DISPERSED (3)")
	assert(not damage_area.monitoring, "DamageArea should be disabled during disperse")
	assert(signal_data["dispersed_duration"] > 0.4 and signal_data["dispersed_duration"] < 0.8, "Disperse duration should be in 0.4~0.7s range")
	assert(float(swarm.get("_disperse_factor")) > 0.5, "Disperse factor should be active")

	_cleanup_root(root)


func _test_purification_lifecycle() -> void:
	var scene: PackedScene = load(SWARM_SCENE_PATH)
	var swarm: Node2D = scene.instantiate() as Node2D
	swarm.set("auto_start", false)
	swarm.set("corruption_hp", 3.0)

	var signal_data := {
		"damages": [],
		"purified": false
	}

	swarm.connect("damaged", func(remaining: float) -> void:
		signal_data["damages"].append(remaining)
	)
	swarm.connect("purified", func() -> void:
		signal_data["purified"] = true
	)

	var root := _create_root()
	root.add_child(swarm)

	swarm.call("hit_by_purification", 1.0)
	assert(is_equal_approx(float(swarm.get("_current_hp")), 2.0), "HP should decrease to 2.0")
	assert(signal_data["damages"].size() == 1, "Damaged signal emitted once")
	assert(not signal_data["purified"], "Should not be purified yet")

	swarm.call("hit_by_purification", 1.0)
	assert(is_equal_approx(float(swarm.get("_current_hp")), 1.0), "HP should decrease to 1.0")
	assert(not signal_data["purified"], "Should not be purified yet")

	swarm.call("hit_by_purification", 1.0)
	assert(is_equal_approx(float(swarm.get("_current_hp")), 0.0), "HP should be 0.0")
	assert(signal_data["purified"], "Purified signal must be emitted upon reaching 0 HP")
	assert(bool(swarm.get("_is_purified")), "Swarm should be marked purified")
	assert(int(swarm.get("_current_state")) == 5, "State should be PURIFIED (5)")

	_cleanup_root(root)


func _test_potion_effect_and_hit_receivers() -> void:
	var scene: PackedScene = load(SWARM_SCENE_PATH)
	var root := _create_root()

	# Test apply_potion_effect with attack
	var swarm1: Node2D = scene.instantiate() as Node2D
	swarm1.set("auto_start", false)
	root.add_child(swarm1)
	swarm1.call("apply_potion_effect", &"attack", {
		"impact_point": swarm1.global_position + Vector2(20, 20),
		"multiplier": 1.0,
		"potency": 1.0
	})
	assert(int(swarm1.get("_current_state")) == 3 or bool(swarm1.get("_is_purified")), "Attack potion should hit swarm")

	# Test apply_potion_effect with purify
	var swarm2: Node2D = scene.instantiate() as Node2D
	swarm2.set("auto_start", false)
	root.add_child(swarm2)
	var hp_before: float = float(swarm2.get("_current_hp"))
	swarm2.call("apply_potion_effect", &"purify", {
		"amount": 1.0,
		"multiplier": 1.0
	})
	var hp_after: float = float(swarm2.get("_current_hp"))
	assert(hp_after < hp_before or bool(swarm2.get("_is_purified")), "Purify effect should reduce corruption hp or purify")

	# Test receive_potion_hit
	var swarm3: Node2D = scene.instantiate() as Node2D
	swarm3.set("auto_start", false)
	root.add_child(swarm3)
	swarm3.call("receive_potion_hit", {
		"potion_id": &"orange_potion",
		"impact_point": swarm3.global_position + Vector2(-30, 0)
	})
	var wind_vel: Vector2 = swarm3.get("_wind_velocity")
	assert(wind_vel.length() > 0.0, "Orange potion hit should impart wind velocity")

	_cleanup_root(root)


func _test_player_damage_and_knockback() -> void:
	var scene: PackedScene = load(SWARM_SCENE_PATH)
	var swarm: Node2D = scene.instantiate() as Node2D
	swarm.set("auto_start", false)
	swarm.set("damage", 12.0)
	swarm.set("knockback_force", 200.0)
	var root := _create_root()
	root.add_child(swarm)

	# Create dummy player
	var dummy_player := DummyPlayer.new()
	dummy_player.add_to_group("player")
	dummy_player.global_position = swarm.global_position + Vector2(20, 0)
	root.add_child(dummy_player)

	swarm.call("start_attack", dummy_player)
	swarm.call("_enter_tracking_state")

	var checked: Dictionary = {}
	swarm.call("_check_and_damage_player", dummy_player, checked)

	assert(dummy_player.hit_received, "Player should receive hit")
	assert(is_equal_approx(dummy_player.last_damage, 12.0), "Damage amount should match")
	assert(dummy_player.last_knockback.x > 0.0, "Knockback should push player away from swarm")

	_cleanup_root(root)


func _test_normal_attack_damage_and_elimination() -> void:
	var scene: PackedScene = load(SWARM_SCENE_PATH)
	var swarm: Node2D = scene.instantiate() as Node2D
	swarm.set("auto_start", false)
	swarm.set("corruption_hp", 3.0)

	var signal_data := { "purified": false }
	swarm.connect("purified", func() -> void: signal_data["purified"] = true)

	var root := _create_root()
	root.add_child(swarm)

	# 1. Normal attack / receive_hit
	swarm.call("receive_hit", 1.5, Vector2.RIGHT * 100.0)
	assert(is_equal_approx(float(swarm.get("_current_hp")), 1.5), "receive_hit should reduce HP by 1.5")
	assert(not signal_data["purified"], "Swarm should still be alive")

	# 2. Normal attack finishing blow
	swarm.call("take_damage", 1.5)
	assert(is_equal_approx(float(swarm.get("_current_hp")), 0.0), "take_damage should reduce HP to 0")
	assert(signal_data["purified"], "Swarm must be eliminated and purified")
	assert(bool(swarm.get("_is_purified")), "Swarm must be marked purified")

	_cleanup_root(root)


func _test_max_active_swarms_limit() -> void:
	var scene: PackedScene = load(SWARM_SCENE_PATH)
	var root := _create_root()
	var spawned: Array[Node2D] = []

	# Spawn up to 4 swarms
	for i in range(4):
		var s: Node2D = scene.instantiate() as Node2D
		root.add_child(s)
		spawned.append(s)

	# Try spawning a 5th swarm -> should be rejected/freed by MAX_CONCURRENT_SWARMS
	var s5: Node2D = scene.instantiate() as Node2D
	root.add_child(s5)
	assert(s5.is_queued_for_deletion(), "5th concurrent swarm must be queued for deletion")

	_cleanup_root(root)


class DummyPlayer extends Node2D:
	var hit_received := false
	var last_damage := 0.0
	var last_knockback := Vector2.ZERO

	func receive_hit(dmg: float, knockback: Vector2) -> void:
		hit_received = true
		last_damage = dmg
		last_knockback = knockback

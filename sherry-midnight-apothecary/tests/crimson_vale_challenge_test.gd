class_name CrimsonValeChallengeTest
extends RefCounted

const CHALLENGE_SCENE_PATH := "res://day/levels/Crimson Vale/crimson_vale_challenge.tscn"
const SHELTER_SCENE_PATH := "res://day/levels/Crimson Vale/hazards/foreground_shelter.tscn"
const SWARM_SCENE_PATH := "res://day/levels/Crimson Vale/hazards/blood_leaf_swarm.tscn"
const CrimsonValeChallengeScript := preload("res://day/levels/Crimson Vale/crimson_vale_challenge.gd")
const ForegroundShelterScript := preload("res://day/levels/Crimson Vale/hazards/foreground_shelter.gd")
const BloodLeafSwarmScript := preload("res://day/levels/Crimson Vale/hazards/blood_leaf_swarm.gd")

var _tree_root: Node


func run(tree_root: Node = null) -> void:
	_tree_root = tree_root
	print("Starting CrimsonValeChallenge & ForegroundShelter unit tests...")
	_test_challenge_scene_structure()
	_test_foreground_shelter_lifecycle()
	_test_blood_leaf_swarm_shelter_evasion()
	_test_abyss_respawn_and_checkpoint()
	print("All CrimsonValeChallenge & ForegroundShelter tests passed successfully!")


func _create_root() -> Node2D:
	var node := Node2D.new()
	if _tree_root != null:
		_tree_root.add_child(node)
	return node


func _cleanup_root(node: Node2D) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()


func _test_challenge_scene_structure() -> void:
	var scene: PackedScene = load(CHALLENGE_SCENE_PATH)
	assert(scene != null, "Challenge scene must exist at %s" % CHALLENGE_SCENE_PATH)

	var level: Node2D = scene.instantiate() as Node2D
	assert(level != null, "Challenge scene should instantiate")
	assert(level is CrimsonValeChallengeScript, "Scene root must be CrimsonValeChallenge")
	assert(level is DayLevelEnvironment, "Scene root must inherit DayLevelEnvironment")

	# Check player and portals
	var player := level.get_node_or_null("Player") as CharacterBody2D
	var exit_portal := level.get_node_or_null("ExitPortal") as DoorPortal
	var gate_portal := level.get_node_or_null("World/DanxinGate/GatePortal") as DoorPortal
	var entry_points := level.get_node_or_null("EntryPoints") as Node2D

	assert(player != null, "Player must exist in challenge scene")
	assert(exit_portal != null, "ExitPortal must exist")
	assert(gate_portal != null, "Danxin GatePortal must exist")
	assert(entry_points != null, "EntryPoints node must exist")
	assert(entry_points.get_node_or_null("default") != null, "Default entry point must exist")

	# Check shelters and swarms
	var shelters := level.get_node_or_null("World/Shelters") as Node2D
	var swarms := level.get_node_or_null("World/Swarms") as Node2D
	var abyss := level.get_node_or_null("World/AbyssHazard") as Area2D

	assert(shelters != null and shelters.get_child_count() >= 3, "Challenge scene must have at least 3 shelters")
	assert(swarms != null and swarms.get_child_count() >= 3, "Challenge scene must have at least 3 blood leaf swarms")
	assert(abyss != null, "Abyss hazard Area2D must exist")

	level.free()


func _test_foreground_shelter_lifecycle() -> void:
	var scene: PackedScene = load(SHELTER_SCENE_PATH)
	assert(scene != null, "Shelter scene must exist at %s" % SHELTER_SCENE_PATH)

	var shelter: Area2D = scene.instantiate() as Area2D
	assert(shelter is ForegroundShelterScript, "Instantiated node must be ForegroundShelter")

	var root := _create_root()
	root.add_child(shelter)

	var dummy_player := CharacterBody2D.new()
	dummy_player.name = "Player"
	root.add_child(dummy_player)

	var signal_data := {
		"entered": false,
		"exited": false
	}
	shelter.connect("shelter_entered", func(_b: Node2D) -> void: signal_data["entered"] = true)
	shelter.connect("shelter_exited", func(_b: Node2D) -> void: signal_data["exited"] = true)

	# Enter shelter
	shelter._on_body_entered(dummy_player)
	assert(signal_data["entered"], "shelter_entered signal should be emitted")
	assert(bool(dummy_player.get_meta("sheltered", false)) == true, "Player must have meta sheltered = true")
	assert(dummy_player.is_in_group("sheltered"), "Player must be added to 'sheltered' group")
	assert(shelter.is_sheltering_player(), "Shelter must report is_sheltering_player() == true")

	# Exit shelter
	shelter._on_body_exited(dummy_player)
	assert(signal_data["exited"], "shelter_exited signal should be emitted")
	assert(bool(dummy_player.get_meta("sheltered", false)) == false, "Player must have meta sheltered = false")
	assert(not dummy_player.is_in_group("sheltered"), "Player must be removed from 'sheltered' group")
	assert(not shelter.is_sheltering_player(), "Shelter must report is_sheltering_player() == false")

	_cleanup_root(root)


func _test_blood_leaf_swarm_shelter_evasion() -> void:
	var swarm_scene: PackedScene = load(SWARM_SCENE_PATH)
	var swarm: Node2D = swarm_scene.instantiate() as Node2D
	swarm.set("auto_start", false)

	var root := _create_root()
	root.add_child(swarm)

	var dummy_player := CharacterBody2D.new()
	dummy_player.name = "Player"
	dummy_player.add_to_group("player")
	dummy_player.global_position = Vector2(100, 100)
	root.add_child(dummy_player)

	# Start attack outside shelter
	swarm.call("start_attack", dummy_player)
	swarm.call("_enter_tracking_state")
	assert(int(swarm.get("_current_state")) == 2, "Swarm should be in TRACKING (2)")

	# Player enters shelter -> swarm loses lock and finishes attack / enters cooldown
	dummy_player.set_meta("sheltered", true)
	dummy_player.add_to_group("sheltered")

	swarm._physics_process(0.1)
	assert(int(swarm.get("_current_state")) == 4 or int(swarm.get("_current_state")) == 0, "Swarm should exit TRACKING to COOLDOWN (4) or IDLE (0) when player enters shelter")

	# While sheltered, swarm in IDLE should NOT lock on even if player is close
	swarm.call("_enter_idle_state")
	swarm._physics_process(0.1)
	assert(int(swarm.get("_current_state")) == 0, "Swarm must remain IDLE while player is sheltered")

	# Player exits shelter -> swarm detects player and starts attack
	dummy_player.set_meta("sheltered", false)
	dummy_player.remove_from_group("sheltered")

	swarm._physics_process(0.1)
	assert(int(swarm.get("_current_state")) == 1, "Swarm should wake up and start TELEGRAPH (1) once player leaves shelter")

	_cleanup_root(root)


func _test_abyss_respawn_and_checkpoint() -> void:
	var scene: PackedScene = load(CHALLENGE_SCENE_PATH)
	var level: Node2D = scene.instantiate() as Node2D
	var root := _create_root()
	root.add_child(level)

	var player := level.get_node_or_null("Player") as CharacterBody2D
	assert(player != null, "Player must exist")

	var initial_pos: Vector2 = player.global_position
	var shelter1: Node2D = level.get_node_or_null("World/Shelters/Shelter1_Rack") as Node2D
	assert(shelter1 != null, "Shelter 1 must exist")

	# Simulate player reaching shelter 1
	player.global_position = shelter1.global_position
	level.call("_on_shelter_entered", player)
	assert(level.get("_last_checkpoint_pos") == shelter1.global_position, "Checkpoint should be updated to shelter 1 position")

	# Simulate falling into abyss
	player.global_position = Vector2(2300, 840) # Inside abyss
	level.call("_on_abyss_body_entered", player)

	# Player should be respawned at last checkpoint
	assert(player.global_position == shelter1.global_position, "Player should be respawned at shelter 1 checkpoint")

	_cleanup_root(root)

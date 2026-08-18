class_name AlkeonBossTest
extends RefCounted

const ARENA_SCENE_PATH := "res://day/levels/Crimson Vale/boss/alkeon_arena.tscn"
const BOSS_SCENE_PATH := "res://day/levels/Crimson Vale/boss/alkeon_boss.tscn"
const SURGE_SCENE_PATH := "res://day/levels/Crimson Vale/boss/blood_leaf_surge.tscn"
const AlkeonArenaScript := preload("res://day/levels/Crimson Vale/boss/alkeon_arena.gd")
const AlkeonBossScript := preload("res://day/levels/Crimson Vale/boss/alkeon_boss.gd")
const BloodLeafSurgeScript := preload("res://day/levels/Crimson Vale/boss/blood_leaf_surge.gd")

var _tree_root: Node


func run(tree_root: Node = null) -> void:
	_tree_root = tree_root
	print("Starting Alkeon Boss & Arena unit tests...")
	_test_arena_scene_structure()
	_test_blood_leaf_surge_mechanics()
	_test_boss_vulnerability_and_phase_progression()
	_test_final_three_step_purification()
	_test_danxin_gate_clock_transformation()
	print("All Alkeon Boss & Arena tests passed successfully!")


func _create_root() -> Node2D:
	var node := Node2D.new()
	if _tree_root != null:
		_tree_root.add_child(node)
	return node


func _cleanup_root(node: Node2D) -> void:
	if node != null and is_instance_valid(node):
		node.queue_free()


func _test_arena_scene_structure() -> void:
	var scene: PackedScene = load(ARENA_SCENE_PATH)
	assert(scene != null, "Arena scene must load from %s" % ARENA_SCENE_PATH)

	var arena: Node2D = scene.instantiate() as Node2D
	assert(arena is AlkeonArenaScript, "Arena root must be AlkeonArena")
	assert(arena is DayLevelEnvironment, "Arena root must inherit DayLevelEnvironment")

	# Check boss, bells, and surges
	var boss := arena.get_node_or_null("Boss") as AlkeonBoss
	var bell_left := arena.get_node_or_null("Bells/BellLeft") as WindChime
	var bell_center := arena.get_node_or_null("Bells/BellCenter") as WindChime
	var bell_right := arena.get_node_or_null("Bells/BellRight") as WindChime
	var surge_left := arena.get_node_or_null("Surges/SurgeLeft") as BloodLeafSurge
	var surge_center := arena.get_node_or_null("Surges/SurgeCenter") as BloodLeafSurge
	var surge_right := arena.get_node_or_null("Surges/SurgeRight") as BloodLeafSurge
	var gate := arena.get_node_or_null("DanxinGate") as Node2D
	var player := arena.get_node_or_null("Player") as CharacterBody2D

	assert(boss != null, "Boss instance must exist in arena")
	assert(bell_left != null and bell_center != null and bell_right != null, "All 3 wind chimes must exist")
	assert(surge_left != null and surge_center != null and surge_right != null, "All 3 zone surges must exist")
	assert(gate != null, "DanxinGate must exist")
	assert(player != null, "Player must exist")

	arena.free()


func _test_blood_leaf_surge_mechanics() -> void:
	var scene: PackedScene = load(SURGE_SCENE_PATH)
	var surge: Area2D = scene.instantiate() as Area2D
	var root := _create_root()
	root.add_child(surge)

	assert(surge is BloodLeafSurgeScript, "Surge must instantiate")

	# Start telegraph
	surge.call("start_telegraph", 0.5)
	assert(int(surge.get("current_state")) == 1, "State should be TELEGRAPH (1)")

	# Force active
	surge.call("_enter_active_state")
	assert(int(surge.get("current_state")) == 2, "State should be ACTIVE (2)")
	assert(surge.monitoring == true, "Surge should be monitoring in ACTIVE state")

	# Use Wind Potion -> creates Headwind Safe Zone
	surge.call("receive_potion_hit", { "potion_id": &"wind" })
	assert(int(surge.get("current_state")) == 3, "State should be HEADWIND_SAFE (3) after wind potion")

	_cleanup_root(root)


func _test_boss_vulnerability_and_phase_progression() -> void:
	var scene: PackedScene = load(BOSS_SCENE_PATH)
	var boss: Node2D = scene.instantiate() as Node2D
	var root := _create_root()
	root.add_child(boss)

	assert(boss is AlkeonBossScript, "Boss must instantiate")
	assert(float(boss.get("current_hp")) == 100.0, "Initial HP must be 100")
	assert(int(boss.get("current_phase")) == 0, "Initial phase must be PHASE1_RED_HORN (0)")

	# Normal state: potion hit on shielded face does no damage
	boss.call("receive_potion_hit", { "potion_id": &"purification" })
	assert(float(boss.get("current_hp")) == 100.0, "Purification on normal head does no damage")

	# Enter Bowed vulnerability window
	boss.call("enter_bowed_state", 3.5)
	assert(int(boss.get("head_state")) == 1, "Head state should be BOWED (1)")

	# Hit 1: Explosion potion breaks shield
	boss.call("receive_potion_hit", { "potion_id": &"explosion" })
	assert(bool(boss.get("_shield_broken")) == true, "Shield should be broken after explosion")

	# Hit 2: Purification potion deals damage
	boss.call("receive_potion_hit", { "potion_id": &"purification" })
	assert(float(boss.get("current_hp")) < 100.0, "Core damage should reduce HP")

	# Simulate damage reducing HP to Phase 2 threshold
	boss.call("_apply_core_damage", 30.0) # HP down to 58.0 <= 67.0
	assert(int(boss.get("current_phase")) == 1 or int(boss.get("current_phase")) == 2, "Boss should transition to Phase 2")

	_cleanup_root(root)


func _test_final_three_step_purification() -> void:
	var scene: PackedScene = load(BOSS_SCENE_PATH)
	var boss: Node2D = scene.instantiate() as Node2D
	var root := _create_root()
	root.add_child(boss)

	var signal_data := { "purified": false }
	boss.connect("boss_purified", func() -> void: signal_data["purified"] = true)

	boss.set("current_phase", 4) # PHASE3_GREAT_HUNT
	boss.set("current_hp", 10.0)

	# Enter Final Purification window
	boss.call("enter_final_purification_window")
	assert(int(boss.get("head_state")) == 2, "Head state should be FINAL_EXPOSED (2)")
	assert(int(boss.get("_final_step")) == 0, "Step 0: Awaiting Explosion")

	# Step 1: Explosion
	boss.call("receive_potion_hit", { "potion_id": &"explosion" })
	assert(int(boss.get("_final_step")) == 1, "Step 1: Awaiting Wind")

	# Step 2: Wind
	boss.call("receive_potion_hit", { "potion_id": &"wind" })
	assert(int(boss.get("_final_step")) == 2, "Step 2: Awaiting Purification")

	# Step 3: Purification -> Triggers Victory
	boss.call("receive_potion_hit", { "potion_id": &"purification" })
	assert(signal_data["purified"] == true, "boss_purified signal must be emitted")
	assert(int(boss.get("current_phase")) == 6, "Boss must enter PURIFIED_RESTORED (6)")

	var restored_sprite := boss.get_node_or_null("RestoredSprite") as Sprite2D
	assert(restored_sprite != null and restored_sprite.visible, "RestoredSprite must become visible upon purification")

	_cleanup_root(root)


func _test_danxin_gate_clock_transformation() -> void:
	var scene: PackedScene = load(ARENA_SCENE_PATH)
	var arena: Node2D = scene.instantiate() as Node2D
	var root := _create_root()
	root.add_child(arena)

	var portal := arena.get_node_or_null("DanxinGate/GatePortal") as DoorPortal
	assert(portal != null, "Gate portal must exist")

	# Trigger purification completion
	arena.call("_on_boss_purified")
	assert(arena.get("is_battle_active") == false, "Battle should be inactive after purification")
	assert(portal.destination_level == &"orem_clocktower", "Destination level must transition to orem_clocktower")

	_cleanup_root(root)

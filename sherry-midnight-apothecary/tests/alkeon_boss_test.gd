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
	_test_weakpoint_indicator_visuals()
	_test_boss_health_bar_hud()
	_test_final_three_step_purification()
	_test_danxin_gate_clock_transformation()
	_test_player_precision_hitbox_core()
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
	var gate := arena.get_node_or_null("Background/CS/DanxinGate") if arena.get_node_or_null("Background/CS/DanxinGate") != null else arena.get_node_or_null("DanxinGate")
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

	# Test Purification Potion also creates Headwind Safe Zone
	surge.call("_enter_active_state")
	surge.call("receive_potion_hit", { "potion_id": &"purification_potion" })
	assert(int(surge.get("current_state")) == 3, "State should be HEADWIND_SAFE (3) after purification potion")

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

	# Test Purification potion directly breaking shield & dealing core damage
	boss.call("receive_potion_hit", { "potion_id": &"purification_potion" })
	assert(float(boss.get("current_hp")) < 100.0, "Purification potion must deal damage directly")

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

	# Enter Final Execution window
	boss.call("enter_final_purification_window")
	assert(int(boss.get("head_state")) == 2, "Head state should be FINAL_EXPOSED (2)")

	# Any potion satisfies final execution
	boss.call("receive_potion_hit", { "potion_id": &"red_potion" })
	assert(int(boss.get("current_phase")) == 6, "Boss must enter PURIFIED_RESTORED (6)")

	_cleanup_root(root)


func _test_weakpoint_indicator_visuals() -> void:
	var scene: PackedScene = load(BOSS_SCENE_PATH)
	var boss: Node2D = scene.instantiate() as Node2D
	var root := _create_root()
	root.add_child(boss)

	var indicator := boss.get_node_or_null("DisasterCore/WeakpointIndicator") as AlkeonWeakpointIndicator
	assert(indicator != null, "WeakpointIndicator must exist under DisasterCore")
	assert(not indicator.visible, "WeakpointIndicator should be hidden initially")

	# Enter Bowed: indicator becomes visible in shield mode
	boss.call("enter_bowed_state", 3.0)
	assert(indicator.visible, "WeakpointIndicator must become visible in bowed state")
	assert(indicator.get("_current_mode") == "shield", "Initial bowed mode should be 'shield'")

	# Break shield: switches to core_exposed mode
	boss.call("_break_shield")
	assert(indicator.get("_current_mode") == "core_exposed", "Mode should change to 'core_exposed' after breaking shield")

	# Raise head: deactivates indicator
	boss.call("raise_head")
	assert(not indicator.get("_is_active"), "Indicator should deactivate when head raised")

	# Final window mode
	boss.call("enter_final_purification_window")
	assert(indicator.get("_current_mode") == "final_execute", "Final window mode is 'final_execute'")

	_cleanup_root(root)


func _test_boss_health_bar_hud() -> void:
	var arena_scene: PackedScene = load(ARENA_SCENE_PATH)
	var arena: Node2D = arena_scene.instantiate() as Node2D
	var root := _create_root()
	root.add_child(arena)

	var boss_hud := arena.get_node_or_null("BossHealthBar") as AlkeonBossHealthBarUI
	assert(boss_hud != null, "BossHealthBar instance must exist in arena")

	var boss := arena.get_node_or_null("Boss") as AlkeonBoss
	assert(boss != null, "Boss must exist")

	var hp_bar := boss_hud.get_node_or_null("%HpBar") as ProgressBar
	var hp_label := boss_hud.get_node_or_null("%HpLabel") as Label
	var phase_badge := boss_hud.get_node_or_null("%PhaseBadge") as Label

	assert(hp_bar != null, "HpBar ProgressBar must exist")
	assert(hp_label != null, "HpLabel must exist")
	assert(phase_badge != null, "PhaseBadge must exist")

	# Check initial 100%
	assert(is_equal_approx(hp_bar.value, 100.0), "Initial HP bar value should be 100%")

	# Test HP reduction update
	boss.call("_apply_core_damage", 25.0)
	assert(is_equal_approx(hp_bar.value, 75.0), "HP bar value should update to 75%")
	assert(hp_label.text.contains("75%"), "HP label text should reflect 75%")

	_cleanup_root(root)


func _test_danxin_gate_clock_transformation() -> void:
	var scene: PackedScene = load(ARENA_SCENE_PATH)
	var arena: Node2D = scene.instantiate() as Node2D
	var root := _create_root()
	root.add_child(arena)

	var portal := arena.get_node_or_null("Background/CS/DanxinGate/GatePortal") if arena.get_node_or_null("Background/CS/DanxinGate/GatePortal") != null else arena.get_node_or_null("DanxinGate/GatePortal")
	var gate_broken := arena.get_node_or_null("Background/CS/DanxinGate/GateBroken") if arena.get_node_or_null("Background/CS/DanxinGate/GateBroken") != null else arena.get_node_or_null("DanxinGate/GateBroken")
	var gate_restored := arena.get_node_or_null("Background/CS/DanxinGate/GateRestored") if arena.get_node_or_null("Background/CS/DanxinGate/GateRestored") != null else arena.get_node_or_null("DanxinGate/GateRestored")

	assert(portal != null, "Gate portal must exist")
	assert(gate_broken != null, "GateBroken must exist")
	assert(gate_restored != null, "GateRestored must exist")

	# Trigger purification completion
	arena.call("_on_boss_purified")
	assert(arena.get("is_battle_active") == false, "Battle should be inactive after purification")
	assert(not gate_broken.visible, "GateBroken must be hidden after purification")
	assert(gate_restored.visible, "GateRestored must be visible (restored to normal)")
	assert(portal.destination_level == &"orem_clocktower", "Destination level must transition to orem_clocktower")

	_cleanup_root(root)


func _test_player_precision_hitbox_core() -> void:
	var scene: PackedScene = load(ARENA_SCENE_PATH)
	var arena: Node2D = scene.instantiate() as Node2D
	var root := _create_root()
	root.add_child(arena)

	var player := arena.get_node_or_null("Player") as CharacterBody2D
	assert(player != null, "Player must exist")

	var hitbox_core := player.get_node_or_null("HitboxCore")
	assert(hitbox_core != null, "HitboxCore must exist under Player")

	# Enable Phase 3 precision hitbox
	arena.call("_enable_player_precision_hitbox", true)
	assert(bool(hitbox_core.get("is_active")) == true, "HitboxCore must become active")
	assert(hitbox_core.visible == true, "HitboxCore must become visible")

	# Disable when not in Phase 3
	arena.call("_enable_player_precision_hitbox", false)
	assert(bool(hitbox_core.get("is_active")) == false, "HitboxCore must become inactive")

	_cleanup_root(root)

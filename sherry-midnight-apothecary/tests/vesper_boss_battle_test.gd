class_name VesperBossBattleTest
extends RefCounted

const BOSS_SCENE := preload("res://day/levels/Vespervale/boss/vesper_director_boss.tscn")
const BEAM_SCENE := preload("res://day/levels/Vespervale/boss/boss_beam_hazard.tscn")
const TRACKER_SCENE := preload("res://day/levels/Vespervale/boss/boss_dream_grasp_tracker.tscn")


static func run(test: TestSupport) -> void:
	test_boss_potion_damage(test)
	test_boss_beam_hazard(test)
	test_tracker_player_targeting_and_platform1(test)


static func test_boss_potion_damage(test: TestSupport) -> void:
	var boss := BOSS_SCENE.instantiate() as CharacterBody2D
	test.expect(boss != null, "VesperDirectorBoss instantiates successfully.")

	test.expect(boss.collision_layer & 1 != 0 or boss.collision_layer & 4 != 0, "Boss collision layer is configured to collide with PotionProjectiles.")

	var initial_hp: float = boss.get("current_hp")
	test.expect(initial_hp > 0.0, "Boss starts with positive HP.")

	# 1. Test direct potion hit via receive_potion_hit
	var dummy_hit := {
		"potion": null,
		"potion_id": &"attack",
		"multiplier": 1.5,
		"amount": 30.0,
		"impact_point": boss.global_position
	}
	boss.call("receive_potion_hit", dummy_hit)
	test.expect(float(boss.get("current_hp")) < initial_hp, "Boss takes damage from receive_potion_hit.")

	# 2. Test purification potion on Moon Shield
	boss.set("is_shield_active", true)
	var hp_before_purify: float = boss.get("current_hp")
	boss.call("apply_potion_effect", &"purify", {"multiplier": 1.0, "amount": 25.0})
	test.expect(not bool(boss.get("is_shield_active")), "Purify potion breaks Moon Shield.")
	test.expect(float(boss.get("current_hp")) < hp_before_purify, "Boss takes damage from purification potion.")

	boss.queue_free()


static func test_boss_beam_hazard(test: TestSupport) -> void:
	var beam := BEAM_SCENE.instantiate() as Area2D
	test.expect(beam != null, "BossBeamHazard instantiates successfully.")

	beam.call("setup_horizontal", 580.0, 20.0, 0.5)
	test.expect_equal(beam.global_position.y, 580.0, "Beam hazard positions at target Y coordinate.")

	beam.queue_free()


static func test_tracker_player_targeting_and_platform1(test: TestSupport) -> void:
	var tracker := TRACKER_SCENE.instantiate() as Node2D
	test.expect(tracker != null, "BossDreamGraspTracker instantiates successfully.")

	var dummy_player := CharacterBody2D.new()
	dummy_player.name = "Player"
	dummy_player.global_position = Vector2(900.0, 610.0)

	tracker.call("setup", dummy_player, -1.0, 1, 15)
	test.expect_equal(tracker.get("_current_x"), 900.0, "Tracker initializes directly at Player's ground projection.")
	test.expect(not tracker.call("is_target_on_platform1"), "Player on ground is targeted by tracker.")

	# Player on Platform1
	dummy_player.global_position = Vector2(400.0, 530.0)
	test.expect(tracker.call("is_target_on_platform1"), "Player on Platform1 is recognized as sheltered from tracking.")

	dummy_player.queue_free()
	tracker.queue_free()

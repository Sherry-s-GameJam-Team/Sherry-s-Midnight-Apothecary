class_name HelionBossTest
extends RefCounted

const TestSupport = preload("res://tests/test_support.gd")
const HelionBossConfigScript = preload("res://day/levels/Aurem Clockyard/boss/helion/battle/helion_boss_config.gd")
const HelionAnimationCuesScript = preload("res://day/levels/Aurem Clockyard/boss/helion/battle/helion_animation_cues.gd")
const HelionBossScript = preload("res://day/levels/Aurem Clockyard/boss/helion/battle/helion_boss.gd")
const HelionRewindRecorderScript = preload("res://day/levels/Aurem Clockyard/boss/helion/battle/player_rewind_recorder.gd")
const HelionBossArenaScript = preload("res://day/levels/Aurem Clockyard/boss/helion/battle/helion_arena.gd")
const HelionClockFloorControllerScript = preload("res://day/levels/Aurem Clockyard/boss/helion/battle/clock_floor_controller.gd")
const HelionBossHUDScript = preload("res://day/levels/Aurem Clockyard/boss/helion/battle/helion_boss_hud.gd")
const HelionTriggerGearScript = preload("res://day/levels/Aurem Clockyard/boss/helion/battle/helion_trigger_gear.gd")


func run(test: RefCounted) -> void:
	print("Running Helion Boss Unit & Integration Tests...")

	# 1. Test Config Resource
	var config: Resource = load("res://day/levels/Aurem Clockyard/boss/helion/battle/helion_boss_config.tres")
	test.expect(config != null, "HelionBossConfig resource loads successfully.")
	if config != null:
		test.expect_equal(config.get("max_hp"), 2000, "Default max_hp is 2000.")
		test.expect_equal(config.get("phase2_threshold"), 0.70, "Phase 2 threshold is 70%.")
		test.expect_equal(config.get("phase3_threshold"), 0.35, "Phase 3 threshold is 35%.")
		test.expect_equal(config.get("final_purify_required"), false, "Final purification is false (regular damage can defeat).")

	# 2. Test Animation Cues Resource
	var cues: Resource = load("res://day/levels/Aurem Clockyard/boss/helion/battle/helion_animation_cues.tres")
	test.expect(cues != null, "HelionAnimationCues resource loads successfully.")
	if cues != null:
		var sweep_on: Array = cues.call("get_cues_at", &"minute_sweep", 4)
		test.expect(sweep_on.has(&"sweep_hitbox_on"), "minute_sweep frame 4 has sweep_hitbox_on cue.")

		var sweep_off: Array = cues.call("get_cues_at", &"minute_sweep", 14)
		test.expect(sweep_off.has(&"sweep_hitbox_off"), "minute_sweep frame 14 has sweep_hitbox_off cue.")

		var rewind_commit: Array = cues.call("get_cues_at", &"rewind_cast", 28)
		test.expect(rewind_commit.has(&"rewind_commit"), "rewind_cast frame 28 has rewind_commit cue.")

		var p3_ready: Array = cues.call("get_cues_at", &"phase3_transform", 24)
		test.expect(p3_ready.has(&"phase3_ready"), "phase3_transform frame 24 has phase3_ready cue.")

		var ring_peak: Array = cues.call("get_cues_at", &"time_ring_burst", 10)
		test.expect(ring_peak.has(&"ring_peak"), "time_ring_burst frame 10 has ring_peak cue.")

	# 3. Test Rewind Recorder
	var recorder: Node = HelionRewindRecorderScript.new()
	recorder.set("record_buffer_seconds", 2.5)
	recorder.set("fallback_position", Vector2(100, 200))

	var arena_rect := Rect2(0, 0, 1000, 600)
	var safe_pos: Vector2 = recorder.call("get_safe_rewind_position", 2.0, arena_rect)
	test.expect(safe_pos != Vector2.ZERO, "Rewind recorder returns safe position even with empty buffer (fallback).")
	recorder.free()

	# 4. Test Boss Scene & State Machine
	var boss_scene: PackedScene = load("res://day/levels/Aurem Clockyard/boss/helion/battle/helion_boss.tscn") as PackedScene
	test.expect(boss_scene != null, "HelionBoss scene loads successfully.")
	if boss_scene != null:
		var boss: Node2D = boss_scene.instantiate() as Node2D
		test.expect(boss != null, "HelionBoss instances successfully.")

		if boss != null:
			# Test begin battle
			boss.call("begin_battle")
			test.expect_equal(int(boss.get("current_phase")), 1, "Boss enters Phase 1 upon battle start.")

			# Test Phase 1 -> Phase 2 transition at 70% HP
			boss.set("current_hp", 1390)
			boss.call("_check_phase_transition")
			test.expect_equal(int(boss.get("current_phase")), 2, "Boss transitions to Phase 2 when HP <= 70%.")

			# Test Phase 2 -> Phase 3 transition at 35% HP
			boss.set("current_hp", 690)
			boss.call("_check_phase_transition")
			test.expect_equal(int(boss.get("current_phase")), 3, "Boss enters Phase 3 transition when HP <= 35%.")

			# Test regular damage reduces HP to 0 and triggers defeat directly
			var defeated_emitted: Array[bool] = [false]
			boss.connect("boss_defeated", func(_id: StringName) -> void:
				defeated_emitted[0] = true
			)
			boss.set("current_hp", 20)
			boss.call("receive_potion_hit", {"damage": 50, "potion_id": "bomb_potion"})
			test.expect_equal(boss.get("current_hp"), 0, "Regular damage can reduce HP to 0 and defeat Helion.")
			test.expect_equal(int(boss.get("current_phase")), 6, "Boss directly enters DEFEATED phase (index 6) on 0 HP.")
			test.expect(defeated_emitted[0], "boss_defeated signal emitted upon defeat.")
			test.expect(not bool(boss.get("is_hostile")), "Boss hostile flag is false upon defeat.")

			boss.free()

	# 5. Test Trigger Gear
	var gear: Area2D = HelionTriggerGearScript.new()
	var gear_activated: Array[bool] = [false]
	gear.connect("activated", func() -> void:
		gear_activated[0] = true
	)
	gear.call("activate")
	test.expect(gear_activated[0], "HelionTriggerGear emits activated signal when activated.")
	gear.free()

	# 6. Test Arena Scene
	var arena_scene: PackedScene = load("res://day/levels/Aurem Clockyard/boss/helion/battle/helion_arena.tscn") as PackedScene
	test.expect(arena_scene != null, "HelionBossArena scene loads successfully.")
	if arena_scene != null:
		var arena: Node2D = arena_scene.instantiate() as Node2D
		test.expect(arena != null, "HelionBossArena instances successfully.")
		if arena != null:
			var clock_floor := arena.get_node_or_null("ClockFloor")
			test.expect(clock_floor != null, "ClockFloor controller is present in Arena.")
			var hud := arena.get_node_or_null("BossHUD")
			test.expect(hud != null, "BossHUD is present in Arena.")
			var trig_gear := arena.get_node_or_null("TriggerGear")
			test.expect(trig_gear != null, "TriggerGear is present in Arena.")
			arena.free()

	print("Helion Boss Unit Tests completed successfully.")
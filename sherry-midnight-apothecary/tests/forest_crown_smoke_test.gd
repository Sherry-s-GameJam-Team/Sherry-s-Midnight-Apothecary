extends SceneTree

const SCENE_PATH := "res://day/levels/forest/crown/forest_crown.tscn"

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		_fail("Unable to load %s" % SCENE_PATH)
		_finish()
		return

	var level := packed.instantiate() as ForestCrownLevel
	root.add_child(level)
	await process_frame
	await process_frame

	# 1. Verify Node Hierarchy Contract
	for path in [
		"Background/CrownBackground",
		"Background/GloomyOverlay",
		"Background/RainLayerFar",
		"Background/RainLayerMid",
		"Background/LightningOverlay",
		"RainLayerForeground",
		"Arena/PlatformSplashes",
		"Arena/MainPlatform",
		"Arena/LeftPlatform",
		"Arena/RightPlatform",
		"Arena/FallZone",
		"Boss",
		"Boss/SeraphSprite",
		"Boss/SeraphNormalSprite",
		"Boss/BossBody",
		"Boss/HaloOuter",
		"Boss/HaloInner",
		"Boss/CorruptionCore",
		"Boss/CorruptionCore/CoreWeakpoint",
		"Hazards/BloodRain",
		"Player",
		"Player/Camera2D",
		"Player/PotionThrower",
		"EntryPoints/default",
		"EntryPoints/from_interior",
		"ExitPortal",
		"UI/PurificationGauge",
		"UI/BossHint",
		"UI/ShockwaveRect",
		"UI/FadeRect",
		"CrownVFX"
	]:
		if level.get_node_or_null(path) == null:
			_fail("Missing node: %s" % path)

	var boss := level.boss
	var vfx := level.vfx

	if boss == null or vfx == null:
		_fail("Boss or VFX controller is null")
		_finish()
		return

	# 2. Test Phase 1: Blood Rain & Halo
	boss.start_encounter()
	if boss.state != SeraphBoss.BossState.BLOOD_RAIN:
		_fail("Boss did not transition to BLOOD_RAIN on start_encounter")
	if not boss.halo_outer.visible:
		_fail("HaloOuter was not visible during BLOOD_RAIN phase")

	# Shatter HaloOuter -> enters PHASE1_EXPOSED
	boss.halo_outer.shatter()
	await process_frame
	if boss.state != SeraphBoss.BossState.PHASE1_EXPOSED:
		_fail("Boss did not enter PHASE1_EXPOSED after halo shattered. State is: %d" % boss.state)

	# Hit with purify potion during PHASE1_EXPOSED -> 70% corruption and enters FEATHER_STORM
	boss.receive_potion_hit({"potion_id": "purification_potion"})
	await process_frame
	if boss.corruption != 70.0:
		_fail("Corruption should be 70.0 after Phase 1 exposure hit, got: %f" % boss.corruption)
	if boss.state != SeraphBoss.BossState.FEATHER_STORM:
		_fail("Boss did not transition to FEATHER_STORM (Phase 2). State is: %d" % boss.state)

	# 3. Test Phase 2: Dual Rings & Weakpoints
	if not boss.halo_outer.visible or not boss.halo_inner.visible:
		_fail("Dual rings should be visible during FEATHER_STORM phase")

	boss.halo_outer.shatter()
	boss.halo_inner.shatter()
	await process_frame
	if boss.state != SeraphBoss.BossState.PHASE2_EXPOSED:
		_fail("Boss did not enter PHASE2_EXPOSED after dual rings shattered. State is: %d" % boss.state)

	# Hit 1 in Phase 2
	boss.receive_potion_hit({"potion_id": "purification_potion"})
	await process_frame
	if boss.corruption != 52.0:
		_fail("Corruption should be 52.0 after 1st Phase 2 hit, got: %f" % boss.corruption)

	# Hit 2 in Phase 2 -> 35% corruption and enters CORRUPTION_CORE
	boss.receive_potion_hit({"potion_id": "purification_potion"})
	await process_frame
	if boss.corruption != 35.0:
		_fail("Corruption should be 35.0 after 2nd Phase 2 hit, got: %f" % boss.corruption)
	if boss.state != SeraphBoss.BossState.CORRUPTION_CORE:
		_fail("Boss did not transition to CORRUPTION_CORE (Phase 3). State is: %d" % boss.state)

	# 4. Test Phase 3: Corruption Core 3 layers
	if not boss.corruption_core.visible:
		_fail("CorruptionCore should be visible in Phase 3")

	# Layer 1
	boss.core_weakpoint.purify()
	await process_frame
	if boss._core_hits != 1:
		_fail("Core hits should be 1 after 1st weakpoint purify")

	# Layer 2
	boss.core_weakpoint.purify()
	await process_frame
	if boss._core_hits != 2:
		_fail("Core hits should be 2 after 2nd weakpoint purify")

	# Layer 3 -> Core destroyed, enters FINAL_PURIFICATION at 1%
	boss.core_weakpoint.purify()
	await process_frame
	if boss.state != SeraphBoss.BossState.FINAL_PURIFICATION:
		_fail("Boss did not transition to FINAL_PURIFICATION after core destroyed. State is: %d" % boss.state)
	if boss.corruption != 1.0:
		_fail("Corruption should be 1.0 in FINAL_PURIFICATION, got: %f" % boss.corruption)

	# 5. Test Final Purification & Resolution
	boss.receive_potion_hit({"potion_id": "purification_potion"})
	await process_frame
	if boss.corruption != 0.0:
		_fail("Corruption should be 0.0 after final purify hit, got: %f" % boss.corruption)
	if boss.state != SeraphBoss.BossState.RESTORED:
		_fail("Boss did not transition to RESTORED state. State is: %d" % boss.state)

	level.queue_free()
	await process_frame
	_finish()

func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)

func _finish() -> void:
	if failures.is_empty():
		print("FOREST_CROWN_SMOKE_TEST: PASS")
		quit(0)
	else:
		print("FOREST_CROWN_SMOKE_TEST: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)

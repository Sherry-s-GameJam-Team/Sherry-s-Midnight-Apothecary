extends SceneTree

const SCENE_PATH := "res://day/levels/forest/crown/forest_crown.tscn"
const PURIFICATION_POTION_PATH := "res://shared/definitions/data/potions/purification_potion.tres"
const PROJECTILE_SCENE_PATH := "res://shared/potions/runtime/potion_projectile.tscn"

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

	var boss := level.boss
	if boss == null:
		_fail("Boss node is null")
		_finish()
		return

	boss.start_encounter()
	await process_frame

	var potion := load(PURIFICATION_POTION_PATH) as PotionData
	var projectile_scene := load(PROJECTILE_SCENE_PATH) as PackedScene
	var throw_tuning := PotionThrowTuning.new()
	var effect_tuning := PotionEffectTuning.new()

	# 1. Test hitting a Weakpoint in mid-air with PotionProjectile
	var weakpoints := boss.halo_outer._weakpoints
	if weakpoints.is_empty():
		_fail("No weakpoints spawned on HaloOuter")
		_finish()
		return

	var target_wp := weakpoints[0]
	var target_pos := target_wp.global_position

	var projectile: PotionProjectile = projectile_scene.instantiate()
	level.add_child(projectile)
	projectile.global_position = target_pos - Vector2(100, 0)
	projectile.configure(Vector2(500, 0), {}, potion, throw_tuning, effect_tuning)

	# Simulate physics steps
	for i in range(10):
		await physics_frame

	if target_wp.is_active():
		_fail("Target weakpoint was not purified by PotionProjectile direct hit in mid-air!")

	# 2. Purify the remaining weakpoint to shatter the ring
	if weakpoints.size() > 1 and weakpoints[1].is_active():
		weakpoints[1].purify()
		await process_frame
		await process_frame

	if boss.state != SeraphBoss.BossState.PHASE1_EXPOSED:
		_fail("Boss should be in PHASE1_EXPOSED after all weakpoints purified, got: %d" % boss.state)

	# 3. Test hitting Boss body directly with PotionProjectile in mid-air
	var boss_body_pos := boss.boss_body_area.global_position
	var boss_proj: PotionProjectile = projectile_scene.instantiate()
	level.add_child(boss_proj)
	boss_proj.global_position = boss_body_pos - Vector2(80, 0)
	boss_proj.configure(Vector2(400, 0), {}, potion, throw_tuning, effect_tuning)

	for i in range(10):
		await physics_frame

	if boss.corruption > 70.0:
		_fail("Boss body did not take purification hit from PotionProjectile in mid-air! Corruption: %f" % boss.corruption)

	level.queue_free()
	await process_frame
	_finish()


func _fail(message: String) -> void:
	failures.append(message)
	push_error(message)


func _finish() -> void:
	if failures.is_empty():
		print("SERAPH_BOSS_POTION_PROJECTILE_INTERACTION_TEST: PASS")
		quit(0)
	else:
		print("SERAPH_BOSS_POTION_PROJECTILE_INTERACTION_TEST: FAIL (%d)" % failures.size())
		for f in failures:
			print("  - ", f)
		quit(1)

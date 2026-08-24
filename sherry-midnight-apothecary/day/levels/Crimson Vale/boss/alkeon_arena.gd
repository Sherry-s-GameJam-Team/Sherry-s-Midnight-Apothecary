class_name AlkeonArena
extends DayLevelEnvironment

signal objective_updated(text: String, hint: String)
signal boss_battle_started
signal boss_battle_completed

@export var arena_title: String = "赤角古道·丹心门前"
@export var is_battle_active: bool = true

@onready var boss: AlkeonBoss = $Boss
@onready var audio_synth: AlkeonAudioSynth = $AudioSynth
@onready var danxin_gate_broken: Sprite2D = get_node_or_null("Background/CS/DanxinGate/GateBroken") if get_node_or_null("Background/CS/DanxinGate/GateBroken") != null else get_node_or_null("DanxinGate/GateBroken")
@onready var danxin_gate_restored: Sprite2D = get_node_or_null("Background/CS/DanxinGate/GateRestored") if get_node_or_null("Background/CS/DanxinGate/GateRestored") != null else get_node_or_null("DanxinGate/GateRestored")
@onready var danxin_gate_clock: Sprite2D = get_node_or_null("Background/CS/DanxinGate/GateClock") if get_node_or_null("Background/CS/DanxinGate/GateClock") != null else get_node_or_null("DanxinGate/GateClock")
@onready var gate_portal: DoorPortal = get_node_or_null("Background/CS/DanxinGate/GatePortal") if get_node_or_null("Background/CS/DanxinGate/GatePortal") != null else get_node_or_null("DanxinGate/GatePortal")
@onready var bell_left: WindChime = $Bells/BellLeft
@onready var bell_center: WindChime = $Bells/BellCenter
@onready var bell_right: WindChime = $Bells/BellRight
@onready var surge_left: BloodLeafSurge = $Surges/SurgeLeft
@onready var surge_center: BloodLeafSurge = $Surges/SurgeCenter
@onready var surge_right: BloodLeafSurge = $Surges/SurgeRight
@onready var swarms_container: Node2D = $Swarms
@onready var player_node: CharacterBody2D = $Player
@onready var victory_leaves: GPUParticles2D = $VictoryLeaves
@onready var boss_health_bar: AlkeonBossHealthBarUI = get_node_or_null("BossHealthBar")
@onready var task_complete_ui: TaskCompleteUI = get_node_or_null("TaskCompleteUI") as TaskCompleteUI

var _bag_zones: Array[int] = []
var _wave_count: int = 0
var _attack_timer: float = 2.0
var _is_ultimate_active: bool = false
var _clock_tick_timer: float = 0.0
var _clock_active: bool = false


func _ready() -> void:
	super._ready()
	_setup_boss_connections()
	_setup_bell_connections()
	_update_gate_visuals()
	_reset_bag()
	if is_battle_active:
		objective_updated.emit("迎战【血叶猎王·阿尔凯昂】！", "观察风铃声响与摆动，躲避致命血叶潮。")


func _ensure_player_battle_potions() -> void:
	var pdata := get_player_data()
	if pdata == null:
		return
	var has_potions := false
	for id in pdata.equipped_potion_ids:
		if id != &"" and pdata.potions.has(id) and not pdata.potions[id].is_empty():
			has_potions = true
			break
	if not has_potions:
		pdata.potions.clear()
		var pure_instances: Array[Dictionary] = []
		var cyan_instances: Array[Dictionary] = []
		var red_instances: Array[Dictionary] = []
		for i in range(10):
			pure_instances.append({
				"potion_id": "purification_potion",
				"instance_uid": "pure_%d" % i,
				"remaining_dose": 1.0,
				"potency": 1.0,
				"quality": 1.0,
				"duration": 1.0,
				"thermal_score": 1.0,
			})
			cyan_instances.append({
				"potion_id": "cyan_potion",
				"instance_uid": "cyan_%d" % i,
				"remaining_dose": 1.0,
				"potency": 1.0,
				"quality": 1.0,
				"duration": 1.0,
				"thermal_score": 1.0,
			})
			red_instances.append({
				"potion_id": "red_potion",
				"instance_uid": "red_%d" % i,
				"remaining_dose": 1.0,
				"potency": 1.0,
				"quality": 1.0,
				"duration": 1.0,
				"thermal_score": 1.0,
			})
		pdata.potions[&"purification_potion"] = pure_instances
		pdata.potions[&"cyan_potion"] = cyan_instances
		pdata.potions[&"red_potion"] = red_instances
		pdata.equip_potion(0, &"purification_potion")
		pdata.equip_potion(1, &"cyan_potion")
		pdata.equip_potion(2, &"red_potion")
		pdata.selected_potion_slot = 0


func _physics_process(delta: float) -> void:
	if not is_battle_active or boss == null:
		return

	if _clock_active:
		_clock_tick_timer -= delta
		if _clock_tick_timer <= 0.0:
			_clock_tick_timer = 0.8
			if audio_synth != null:
				audio_synth.play_clock_tick()

	# Battle wave progression loop
	if boss.current_phase != AlkeonBoss.Phase.PURIFIED_RESTORED and not boss._is_transitioning and boss.head_state == AlkeonBoss.HeadState.NORMAL:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_execute_next_attack_cycle()


func _execute_next_attack_cycle() -> void:
	if boss == null:
		return

	match boss.current_phase:
		AlkeonBoss.Phase.PHASE1_RED_HORN:
			_execute_phase1_attack()
		AlkeonBoss.Phase.PHASE2_WILD_HUNT:
			_execute_phase2_attack()
		AlkeonBoss.Phase.PHASE3_GREAT_HUNT:
			if boss.current_hp <= 10.0 and not _is_ultimate_active:
				_execute_ultimate_skill()
			else:
				_execute_phase3_pattern()


func _execute_phase1_attack() -> void:
	_wave_count += 1
	var target_zone := _draw_from_bag()

	# 1. Telegraph: Bell ding 1 ("当——") + wind chime sway
	_telegraph_zone(target_zone, 1.5)

	# 2. Periodically spawn Swarm in safe zone to pressure player
	if _wave_count % 2 == 0:
		var safe_zone := (target_zone + 1) % 3
		_spawn_pressure_swarm(safe_zone, 0.65)

	# 3. Boss vulnerability window every 3 waves
	if _wave_count % 3 == 0:
		_attack_timer = 5.5
		get_tree().create_timer(1.8).timeout.connect(func() -> void:
			if boss != null and boss.current_phase == AlkeonBoss.Phase.PHASE1_RED_HORN:
				boss.enter_bowed_state(3.5)
		)
	else:
		_attack_timer = 3.6


const LAYER_UPPER: float = 180.0
const LAYER_MIDDLE: float = 330.0
const LAYER_LOWER: float = 480.0


func _execute_phase2_attack() -> void:
	_wave_count += 1
	_clear_phase1_swarms()

	# Track player's current vertical layer
	var player_y := player_node.global_position.y if player_node != null else LAYER_LOWER
	var layers: Array[float] = [LAYER_UPPER, LAYER_MIDDLE, LAYER_LOWER]
	var closest_layer := LAYER_LOWER
	var min_diff := 9999.0
	for ly in layers:
		var diff := absf(player_y - ly)
		if diff < min_diff:
			min_diff = diff
			closest_layer = ly

	# Always cover 2 layers simultaneously (player's tracked layer + 1 other layer, leaving 1 safe layer)
	var target_layers: Array[float] = [closest_layer]
	var remaining := layers.filter(func(l: float) -> bool: return l != closest_layer)
	if not remaining.is_empty():
		target_layers.append(remaining.pick_random())

	var dir: float = 1.0 if (_wave_count % 2 == 1) else -1.0
	for ly in target_layers:
		_spawn_shockwave(ly, dir, 0.85)

	# Boss vulnerability window every 3 waves
	if _wave_count % 3 == 0:
		_attack_timer = 4.5
		get_tree().create_timer(1.4).timeout.connect(func() -> void:
			if boss != null and boss.current_phase == AlkeonBoss.Phase.PHASE2_WILD_HUNT:
				boss.enter_bowed_state(3.0)
		)
	else:
		_attack_timer = 2.6


func _spawn_shockwave(layer_y: float, direction: float, telegraph_time: float) -> void:
	var shockwave_scene: PackedScene = load("res://day/levels/Crimson Vale/boss/blood_leaf_shockwave.tscn")
	if shockwave_scene == null:
		return
	var wave: Area2D = shockwave_scene.instantiate() as Area2D
	add_child(wave)
	if wave.has_method("start_shockwave"):
		wave.call("start_shockwave", layer_y, direction, telegraph_time)


func _execute_phase3_pattern() -> void:
	_wave_count += 1
	var pattern_type := _wave_count % 3
	var boss_core_pos: Vector2 = (boss.global_position + Vector2(0, -60)) if boss != null else Vector2(850, 220)

	objective_updated.emit("万叶狂澜！专注走位躲避四周红黄血叶！", "弹幕发射期间仅需走位规避，弹幕结束后猎王将暴露破绽！")

	match pattern_type:
		0: # Spaced Twin Rings: 12 leaves now, followed by 12 leaves offset by 15 deg
			_spawn_bullet_ring(boss_core_pos, 12, 250.0, 0.0)
			get_tree().create_timer(0.7).timeout.connect(func() -> void:
				if is_battle_active and boss != null and boss.current_phase == AlkeonBoss.Phase.PHASE3_GREAT_HUNT:
					_spawn_bullet_ring(boss_core_pos, 12, 280.0, PI / 12.0)
			)
		1: # Spaced Quadrant Clusters (8 cardinal & diagonal leaves, then 8 rotated leaves)
			_spawn_bullet_ring(boss_core_pos, 8, 260.0, 0.0)
			get_tree().create_timer(0.65).timeout.connect(func() -> void:
				if is_battle_active and boss != null and boss.current_phase == AlkeonBoss.Phase.PHASE3_GREAT_HUNT:
					_spawn_bullet_ring(boss_core_pos, 8, 300.0, PI / 8.0)
			)
		2: # Orbiting 3-wave flower bursts (6 spaced leaves per burst)
			for w in range(3):
				get_tree().create_timer(float(w) * 0.45).timeout.connect(func() -> void:
					if is_battle_active and boss != null and boss.current_phase == AlkeonBoss.Phase.PHASE3_GREAT_HUNT:
						_spawn_bullet_ring(boss_core_pos, 6, 270.0, float(w) * (PI / 6.0))
				)

	# After barrage clears (2.2s), open Boss vulnerability window for counterattack!
	get_tree().create_timer(2.2).timeout.connect(func() -> void:
		if is_battle_active and boss != null and boss.current_phase == AlkeonBoss.Phase.PHASE3_GREAT_HUNT:
			objective_updated.emit("【猎王破绽暴露！】趁机投掷药水重创灾核！", "投掷任意药水直接造成巨额伤害！")
			boss.enter_bowed_state(3.5)
	)

	_attack_timer = 6.0


func _spawn_bullet_ring(origin: Vector2, count: int, speed: float, angle_offset: float = 0.0) -> void:
	var bullet_scene: PackedScene = load("res://day/levels/Crimson Vale/boss/blood_leaf_bullet.tscn")
	if bullet_scene == null:
		return
	var angle_step := TAU / float(count)
	for i in range(count):
		var bullet: Area2D = bullet_scene.instantiate() as Area2D
		add_child(bullet)
		bullet.global_position = origin
		var dir := Vector2.RIGHT.rotated(angle_offset + float(i) * angle_step)
		if bullet.has_method("launch"):
			bullet.call("launch", dir, speed)


func _execute_ultimate_skill() -> void:
	_is_ultimate_active = true
	_attack_timer = 15.0
	objective_updated.emit("【万叶归猎】！全场血叶袭来！", "使用【御风药水】制造安全区，并投掷任意药水执行处决！")

	# Sequence bells L -> C -> R out of sync
	if audio_synth != null:
		audio_synth.play_chime_select(0)
		get_tree().create_timer(0.3).timeout.connect(func() -> void: audio_synth.play_chime_select(1))
		get_tree().create_timer(0.6).timeout.connect(func() -> void: audio_synth.play_chime_select(2))

	if bell_left != null: bell_left.call("ring_all", 3.0)
	if bell_center != null: bell_center.call("ring_all", 3.0)
	if bell_right != null: bell_right.call("ring_all", 3.0)

	# Telegraph and activate all 3 surges
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		if surge_left != null: surge_left.start_telegraph(0.4)
		if surge_center != null: surge_center.start_telegraph(0.4)
		if surge_right != null: surge_right.start_telegraph(0.4)
	)

	# Open Final Execution Window
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if boss != null:
			objective_updated.emit("灾核外露！投掷【任意药水】执行处决！", "投掷任意药水即可完成最终净化！")
			boss.enter_final_purification_window()
	)


func _clear_phase1_swarms() -> void:
	if swarms_container != null:
		for child in swarms_container.get_children():
			child.queue_free()


func _clear_all_hazards() -> void:
	_clear_phase1_swarms()
	for shockwave in get_tree().get_nodes_in_group("blood_leaf_shockwave"):
		if shockwave is Node and is_instance_valid(shockwave):
			shockwave.queue_free()
	for bullet in get_tree().get_nodes_in_group("blood_leaf_bullet"):
		if bullet is Node and is_instance_valid(bullet):
			bullet.queue_free()


func _telegraph_zone(zone: int, duration: float) -> void:
	if audio_synth != null:
		audio_synth.play_chime_select(zone)
	_ring_bell(zone, 1.8)

	get_tree().create_timer(duration * 0.55).timeout.connect(func() -> void:
		if audio_synth != null:
			audio_synth.play_chime_urgent(zone)
		_ring_bell(zone, 3.2)
	)

	var surge := _get_surge(zone)
	if surge != null:
		surge.start_telegraph(duration)


func _ring_bell(zone: int, strength: float) -> void:
	var bell: WindChime = null
	match zone:
		0: bell = bell_left
		1: bell = bell_center
		2: bell = bell_right
	if bell != null and bell.has_method("ring_all"):
		bell.call("ring_all", strength)


func _get_surge(zone: int) -> BloodLeafSurge:
	match zone:
		0: return surge_left
		1: return surge_center
		2: return surge_right
	return null


func _spawn_pressure_swarm(zone: int, delay: float) -> void:
	if swarms_container == null:
		return
	var active_count := 0
	for child in swarms_container.get_children():
		if child is BloodLeafSwarm and not bool(child.get("_is_purified")):
			active_count += 1
	if active_count >= 4:
		return

	var swarm_scene: PackedScene = load("res://day/levels/Crimson Vale/hazards/blood_leaf_swarm.tscn")
	if swarm_scene == null:
		return
	var swarm: Node2D = swarm_scene.instantiate() as Node2D
	var zone_x := 275.0 + float(zone) * 550.0
	swarm.position = Vector2(zone_x, 300.0)
	swarm.set("tracking_delay", delay)
	swarms_container.add_child(swarm)
	if player_node != null and swarm.has_method("start_attack"):
		swarm.call("start_attack", player_node)


func _setup_boss_connections() -> void:
	if boss == null:
		return
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.boss_purified.connect(_on_boss_purified)
	if boss_health_bar != null:
		boss_health_bar.setup_boss(boss)


func _setup_bell_connections() -> void:
	var bells: Array[WindChime] = [bell_left, bell_center, bell_right]
	for i in range(bells.size()):
		var bell: WindChime = bells[i]
		if bell != null and bell.has_signal("chime_struck"):
			bell.chime_struck.connect(func(_idx: int, strength: float) -> void:
				if strength > 5.0:
					var surge := _get_surge(i)
					if surge != null:
						surge.delay_attack(1.0)
			)


func apply_potion_effect(effect_id: StringName, context: Dictionary = {}) -> void:
	var eid_str := String(effect_id).to_lower()
	if eid_str.contains("wind") or eid_str.contains("cyan") or eid_str.contains("purification") or eid_str.contains("pure") or eid_str.contains("gust"):
		var splash_pos: Vector2 = context.get("position", Vector2.ZERO)
		var zone := clampi(int(splash_pos.x / 570.0), 0, 2)
		var surge := _get_surge(zone)
		if surge != null:
			surge.make_headwind_safe(2.0)


func _on_boss_phase_changed(new_phase: int) -> void:
	match new_phase:
		AlkeonBoss.Phase.TRANSITION_1_TO_2, AlkeonBoss.Phase.PHASE2_WILD_HUNT:
			_clear_phase1_swarms()
			_enable_player_precision_hitbox(false)
			objective_updated.emit("猎王狂暴！进入第二阶段【狂猎再临】！", "上中下三层血叶冲击波袭来！利用平台跳跃与下落规避伤害。")
			if audio_synth != null:
				audio_synth.play_chime_urgent(0)
				audio_synth.play_chime_urgent(1)
				audio_synth.play_chime_urgent(2)
		AlkeonBoss.Phase.TRANSITION_2_TO_3, AlkeonBoss.Phase.PHASE3_GREAT_HUNT:
			_clear_all_hazards()
			_enable_player_precision_hitbox(true)
			objective_updated.emit("灾核全面外露！进入第三阶段【万叶大猎】！", "中心红点为受击判定核心！躲避密集弹幕，持续投掷药水攻击鹿头！")


func _enable_player_precision_hitbox(enabled: bool) -> void:
	if player_node != null:
		var hitbox_core = player_node.get_node_or_null("HitboxCore")
		if hitbox_core == null and enabled:
			var core_scene: PackedScene = load("res://day/levels/Crimson Vale/boss/player_hitbox_core.tscn")
			if core_scene != null:
				hitbox_core = core_scene.instantiate()
				hitbox_core.name = "HitboxCore"
				hitbox_core.position = Vector2(0, 38)
				player_node.add_child(hitbox_core)
		if hitbox_core != null:
			if enabled:
				hitbox_core.call("activate")
			else:
				hitbox_core.call("deactivate")


func _on_boss_purified() -> void:
	is_battle_active = false
	boss_battle_completed.emit()
	_enable_player_precision_hitbox(false)
	objective_updated.emit("【血叶猎王·阿尔凯昂】净化完成！", "丹心门已恢复。靠近大门并按[E]返回药水铺，开始晚间营业。")

	# Stop all surges and swarms
	_clear_all_hazards()
	if surge_left != null: surge_left._set_state(BloodLeafSurge.State.IDLE)
	if surge_center != null: surge_center._set_state(BloodLeafSurge.State.IDLE)
	if surge_right != null: surge_right._set_state(BloodLeafSurge.State.IDLE)

	if victory_leaves != null:
		victory_leaves.emitting = true

	# Restore gate from broken to normal
	if danxin_gate_broken != null:
		danxin_gate_broken.visible = false
	if danxin_gate_restored != null:
		danxin_gate_restored.visible = true
		danxin_gate_restored.modulate.a = 1.0

	# Restore the gate, then let its dedicated completion portal end the day.
	_trigger_gate_clock_transformation()
	_present_completion_ui()


func _trigger_gate_clock_transformation() -> void:
	if audio_synth != null:
		audio_synth.play_chime_select(0)
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			audio_synth.play_chime_select(1)
		)
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			audio_synth.play_chime_select(2)
		)
		get_tree().create_timer(1.8).timeout.connect(func() -> void:
			audio_synth.play_grand_clock_toll()
			_clock_active = true
		)

	if gate_portal is AlkeonCompletionGate:
		gate_portal.set_night_return_enabled(true)


func _present_completion_ui() -> void:
	if task_complete_ui == null:
		return
	task_complete_ui.present(
		"任务完成：净化血叶猎王",
		"阿尔凯昂已从血叶灾祸中解脱，丹心门重新亮起归途。",
		"关闭此提示后，前往丹心门按[E]返回药水铺"
	)


func _update_gate_visuals() -> void:
	if danxin_gate_broken != null:
		danxin_gate_broken.visible = true
	if danxin_gate_restored != null:
		danxin_gate_restored.visible = false
		danxin_gate_restored.modulate.a = 1.0
	if danxin_gate_clock != null:
		danxin_gate_clock.visible = false


func _draw_from_bag() -> int:
	if _bag_zones.is_empty():
		_reset_bag()
	return _bag_zones.pop_back()


func _reset_bag() -> void:
	_bag_zones = [0, 1, 2]
	_bag_zones.shuffle()

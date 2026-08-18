class_name AlkeonArena
extends DayLevelEnvironment

signal objective_updated(text: String, hint: String)
signal boss_battle_started
signal boss_battle_completed

@export var arena_title: String = "赤角古道·丹心门前"
@export var is_battle_active: bool = true

@onready var boss: AlkeonBoss = $Boss
@onready var audio_synth: AlkeonAudioSynth = $AudioSynth
@onready var danxin_gate_broken: Sprite2D = $DanxinGate/GateBroken
@onready var danxin_gate_restored: Sprite2D = $DanxinGate/GateRestored
@onready var danxin_gate_clock: Sprite2D = $DanxinGate/GateClock
@onready var gate_portal: DoorPortal = $DanxinGate/GatePortal
@onready var bell_left: WindChime = $Bells/BellLeft
@onready var bell_center: WindChime = $Bells/BellCenter
@onready var bell_right: WindChime = $Bells/BellRight
@onready var surge_left: BloodLeafSurge = $Surges/SurgeLeft
@onready var surge_center: BloodLeafSurge = $Surges/SurgeCenter
@onready var surge_right: BloodLeafSurge = $Surges/SurgeRight
@onready var swarms_container: Node2D = $Swarms
@onready var player_node: CharacterBody2D = $Player
@onready var victory_leaves: GPUParticles2D = $VictoryLeaves

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


func _execute_phase2_attack() -> void:
	_wave_count += 1
	var safe_zone := randi() % 3
	var danger_zones: Array[int] = []
	for z in range(3):
		if z != safe_zone:
			danger_zones.append(z)

	# Dual zone telegraph
	for dz in danger_zones:
		_telegraph_zone(dz, 1.4)

	# Staggered swarm pressure
	if _wave_count % 2 == 0:
		_spawn_pressure_swarm(safe_zone, 0.45)

	if _wave_count % 3 == 0:
		_attack_timer = 5.2
		get_tree().create_timer(1.6).timeout.connect(func() -> void:
			if boss != null and boss.current_phase == AlkeonBoss.Phase.PHASE2_WILD_HUNT:
				boss.enter_bowed_state(3.0)
		)
	else:
		_attack_timer = 3.8


func _execute_phase3_pattern() -> void:
	_wave_count += 1
	var patterns := [
		[0, 1, 2],       # Pattern A: L -> C -> R
		[0, 1, 2, 1],    # Pattern B: L+C -> R -> C
		[2, 0, 1],       # Pattern C: R -> L -> C
		[1, 0, 2]        # Pattern D: C -> L -> R
	]
	var chosen_pattern: Array = patterns[_wave_count % patterns.size()]

	# False bell chance
	if randf() < 0.4:
		if audio_synth != null:
			audio_synth.play_false_bell()

	for i in range(chosen_pattern.size()):
		var z: int = chosen_pattern[i]
		get_tree().create_timer(float(i) * 1.1).timeout.connect(func() -> void:
			_telegraph_zone(z, 1.1)
		)

	if _wave_count % 3 == 0 and boss.current_hp > 10.0:
		_attack_timer = 5.0
		get_tree().create_timer(2.2).timeout.connect(func() -> void:
			if boss != null and boss.current_phase == AlkeonBoss.Phase.PHASE3_GREAT_HUNT:
				boss.enter_bowed_state(3.0)
		)
	else:
		_attack_timer = 4.2


func _execute_ultimate_skill() -> void:
	_is_ultimate_active = true
	_attack_timer = 15.0
	objective_updated.emit("【万叶归猎】！全场血叶袭来！", "使用【御风药水】强行制造逆风安全区！")

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

	# After 3.5s of ultimate, open Final Purification Window
	get_tree().create_timer(4.5).timeout.connect(func() -> void:
		if boss != null:
			objective_updated.emit("灾核外露！执行终极净化！", "顺序使用：爆炸药水(碎甲) → 御风药水(定风) → 净化药水(净核)！")
			boss.enter_final_purification_window()
	)


func _telegraph_zone(zone: int, duration: float) -> void:
	# 1. Chime toll & sway
	if audio_synth != null:
		audio_synth.play_chime_select(zone)
	_ring_bell(zone, 1.8)

	# 2. Urgent chime before impact
	get_tree().create_timer(duration * 0.55).timeout.connect(func() -> void:
		if audio_synth != null:
			audio_synth.play_chime_urgent(zone)
		_ring_bell(zone, 3.2)
	)

	# 3. Trigger Surge
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


func _setup_bell_connections() -> void:
	# Connecting wind chimes hit detection: explosion delays active surge
	var bells: Array[WindChime] = [bell_left, bell_center, bell_right]
	for i in range(bells.size()):
		var bell: WindChime = bells[i]
		if bell != null and bell.has_signal("chime_struck"):
			bell.chime_struck.connect(func(_idx: int, strength: float) -> void:
				if strength > 5.0: # Explosion hit
					var surge := _get_surge(i)
					if surge != null:
						surge.delay_attack(1.0)
			)


func _on_boss_phase_changed(new_phase: int) -> void:
	match new_phase:
		AlkeonBoss.Phase.TRANSITION_1_TO_2:
			objective_updated.emit("猎王暴怒！进入第二阶段【狂猎再临】！", "双区同时封锁，寻找唯一安全版面或用【御风药水】破局。")
			if audio_synth != null:
				audio_synth.play_chime_urgent(0)
				audio_synth.play_chime_urgent(1)
				audio_synth.play_chime_urgent(2)
		AlkeonBoss.Phase.TRANSITION_2_TO_3:
			objective_updated.emit("灾厄狂化！进入第三阶段【万叶大猎】！", "警惕虚假风铃！以版面实际风铃晃动为准。")


func _on_boss_purified() -> void:
	is_battle_active = false
	boss_battle_completed.emit()
	objective_updated.emit("【血叶猎王·阿尔凯昂】净化完成！", "丹心门已启动，古钟轰鸣，通往【奥雷姆钟庭】。")

	# Stop all surges and swarms
	if surge_left != null: surge_left._set_state(BloodLeafSurge.State.IDLE)
	if surge_center != null: surge_center._set_state(BloodLeafSurge.State.IDLE)
	if surge_right != null: surge_right._set_state(BloodLeafSurge.State.IDLE)

	if victory_leaves != null:
		victory_leaves.emitting = true

	# Play Danxin Gate -> Orem Clocktower transformation
	_trigger_gate_clock_transformation()


func _trigger_gate_clock_transformation() -> void:
	# 1. Chimes toll sequentially L -> C -> R
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

	# 2. Gate visual shifts to Orange-Gold clockwork gear gate
	if danxin_gate_restored != null and danxin_gate_clock != null:
		var tw := create_tween()
		tw.tween_property(danxin_gate_restored, "modulate:a", 0.0, 1.5)
		tw.parallel().tween_property(danxin_gate_clock, "modulate:a", 1.0, 1.5)

	if gate_portal != null:
		gate_portal.destination_level = &"orem_clocktower"
		gate_portal.fallback_scene_path = "res://day/levels/home/home.tscn"
		gate_portal.interaction_hint_text = "前往【奥雷姆钟庭】"
		gate_portal.monitoring = true
		gate_portal.visible = true


func _update_gate_visuals() -> void:
	if danxin_gate_broken != null:
		danxin_gate_broken.visible = false
	if danxin_gate_restored != null:
		danxin_gate_restored.visible = true
		danxin_gate_restored.modulate.a = 1.0
	if danxin_gate_clock != null:
		danxin_gate_clock.visible = true
		danxin_gate_clock.modulate.a = 0.0


func _draw_from_bag() -> int:
	if _bag_zones.is_empty():
		_reset_bag()
	return _bag_zones.pop_back()


func _reset_bag() -> void:
	_bag_zones = [0, 1, 2]
	_bag_zones.shuffle()

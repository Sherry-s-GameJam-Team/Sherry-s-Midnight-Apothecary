class_name HelionBoss
extends Node2D
## 十二刻守望者·赫利昂  /  Helion, Warden of the Twelve
##
## Main boss controller with dual state machine (Phase + AttackState),
## active bullet hell/barrage attack execution, smooth floating hover effect,
## and potion-responsive core vulnerability mechanics.

# ─── Signals ───
signal health_changed(current_hp: int, max_hp: int)
signal phase_changed(new_phase: int)
signal core_exposed(is_exposed: bool)
signal boss_defeated(boss_id: StringName)
signal boss_started
signal attack_state_changed(new_state: int)

# ─── Enums ───
enum Phase {
	INTRO,
	PHASE_1,
	PHASE_2,
	PHASE_3_TRANSITION,
	PHASE_3,
	PURIFICATION_REQUIRED,
	DEFEATED,
}

enum AttackState {
	IDLE,
	SWEEP,
	CLOCK_DROP,
	REWIND,
	RING_BURST,
	TRANSFORM,
	RECOVERY,
}

# ─── Config ───
@export var config: HelionBossConfig
@export var cues_resource: HelionAnimationCues

# ─── State ───
var current_phase: Phase = Phase.INTRO
var current_attack: AttackState = AttackState.IDLE
var current_hp: int = 2000
var is_core_exposed: bool = false
var is_hostile: bool = true
var is_battle_active: bool = false

const HelionBarrageControllerScript = preload("res://day/levels/Aurem Clockyard/boss/helion/battle/helion_barrage_controller.gd")

var _last_attacks: Array[AttackState] = []
var _phase3_transform_played: bool = false
var _final_sequence_started: bool = false
var _purify_hit_received: bool = false
var _hit_count_since_sweep: int = 0

# Floating / Bobbing motion
var _float_time: float = 0.0
var _base_visual_pos: Vector2 = Vector2.ZERO
var _barrage_ctrl: Node2D = null

# ─── Node References ───
@onready var visual_root: Node2D = $VisualRoot
@onready var sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var core_glow: CanvasItem = $VisualRoot/CoreGlow
@onready var hit_flash: CanvasItem = $VisualRoot/HitFlash
@onready var body_hurtbox: Area2D = $Hurtboxes/BodyHurtbox
@onready var core_hurtbox: Area2D = $Hurtboxes/CoreHurtbox
@onready var sweep_root: Node2D = $AttackRoot/SweepRoot
@onready var projectile_root: Node2D = $AttackRoot/ProjectileRoot
@onready var ring_fx_root: Node2D = $AttackRoot/RingFXRoot
@onready var rewind_fx_root: Node2D = $AttackRoot/RewindFXRoot
@onready var rewind_recorder: Node = $RewindRecorder
@onready var attack_timer: Timer = $AttackTimer
@onready var audio_root: Node2D = $AudioRoot

var _hit_feedback: Node = null
var _player: Node2D = null
var _arena: Node2D = null


func _ready() -> void:
	add_to_group("potion_target")
	add_to_group("boss")

	if config != null:
		current_hp = config.max_hp

	if visual_root != null:
		_base_visual_pos = visual_root.position

	# Initialize Barrage Controller
	_barrage_ctrl = HelionBarrageControllerScript.new()
	_barrage_ctrl.name = "BarrageController"
	_barrage_ctrl.call("setup", self)
	if projectile_root != null:
		projectile_root.add_child(_barrage_ctrl)
	else:
		add_child(_barrage_ctrl)

	# Connect sprite frame changes for cue dispatch
	if sprite != null:
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		sprite.animation_finished.connect(_on_animation_finished)

	# Connect attack timer
	if attack_timer != null:
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)

	# Body hurtbox starts active on layer 4 for potion collisions
	if body_hurtbox != null:
		body_hurtbox.collision_layer = 4
		body_hurtbox.collision_mask = 0
		body_hurtbox.monitoring = true
		body_hurtbox.monitorable = true

	# Core hurtbox starts disabled
	if core_hurtbox != null:
		core_hurtbox.collision_layer = 4
		core_hurtbox.collision_mask = 0
		core_hurtbox.monitorable = false
		core_hurtbox.monitoring = false

	# Hit flash starts invisible
	if hit_flash != null:
		hit_flash.modulate.a = 0.0

	# Find hit feedback node
	_hit_feedback = get_node_or_null("HitFeedback")
	if _hit_feedback == null:
		for child: Node in get_children():
			if child.has_method("play_hit"):
				_hit_feedback = child
				break


func _process(delta: float) -> void:
	# Floating / Bobbing hover motion
	_float_time += delta * 2.2
	if visual_root != null:
		var bob_y := sin(_float_time) * 16.0
		var sway_x := sin(_float_time * 0.7) * 5.0
		visual_root.position = _base_visual_pos + Vector2(sway_x, bob_y)


func set_arena(arena: Node2D) -> void:
	_arena = arena


func begin_battle() -> void:
	is_battle_active = true
	is_hostile = true
	boss_started.emit()
	_find_player()
	_set_phase(Phase.PHASE_1)
	_play_animation(HelionAnimationMap.IDLE)
	_schedule_next_attack()

	if rewind_recorder != null and rewind_recorder.has_method("start_recording"):
		rewind_recorder.call("start_recording")


# ─── PHASE STATE MACHINE ───

func _set_phase(new_phase: Phase) -> void:
	if current_phase == new_phase:
		return
	current_phase = new_phase
	phase_changed.emit(int(new_phase))

	match new_phase:
		Phase.PHASE_1:
			pass
		Phase.PHASE_2:
			if rewind_recorder != null and rewind_recorder.has_method("start_recording"):
				rewind_recorder.call("start_recording")
		Phase.PHASE_3_TRANSITION:
			_begin_phase3_transition()
		Phase.PHASE_3:
			_phase3_transform_played = true
		Phase.PURIFICATION_REQUIRED:
			_enter_purification_required()
		Phase.DEFEATED:
			_enter_defeated()


func _check_phase_transition() -> void:
	if config == null or current_phase == Phase.DEFEATED:
		return

	var hp_ratio: float = float(current_hp) / float(config.max_hp)

	if config.final_purify_required and current_hp <= 1:
		_set_phase(Phase.PURIFICATION_REQUIRED)
		return
	elif not config.final_purify_required and current_hp <= 0:
		_set_phase(Phase.DEFEATED)
		return

	match current_phase:
		Phase.PHASE_1:
			if hp_ratio <= config.phase2_threshold:
				_set_phase(Phase.PHASE_2)
		Phase.PHASE_2:
			if hp_ratio <= config.phase3_threshold:
				_set_phase(Phase.PHASE_3_TRANSITION)
		Phase.PHASE_3_TRANSITION, Phase.PHASE_3:
			if not _final_sequence_started and hp_ratio <= config.final_sequence_threshold:
				_begin_final_sequence()


func _begin_phase3_transition() -> void:
	if _phase3_transform_played:
		_set_phase(Phase.PHASE_3)
		return

	_set_attack_state(AttackState.TRANSFORM)
	_play_animation(HelionAnimationMap.PHASE3_TRANSFORM)
	_emit_audio_cue(&"phase3_transform")

	# Screen blast
	if _barrage_ctrl != null:
		_barrage_ctrl.spawn_celestial_dial_burst(global_position + Vector2(0, -60), 18)


func _begin_final_sequence() -> void:
	_final_sequence_started = true
	if attack_timer != null:
		attack_timer.stop()

	var floor_ctrl: Node = _find_floor_controller()
	if floor_ctrl != null and floor_ctrl.has_method("run_final_twelve_tolls"):
		if floor_ctrl.has_signal("final_tolls_finished"):
			if not floor_ctrl.is_connected("final_tolls_finished", _on_final_tolls_finished):
				floor_ctrl.connect("final_tolls_finished", _on_final_tolls_finished, CONNECT_ONE_SHOT)
		floor_ctrl.call("run_final_twelve_tolls",
			config.final_toll_duration if config else 9.0,
			config.toll_interval if config else 0.75)


func _on_final_tolls_finished() -> void:
	_set_attack_state(AttackState.RING_BURST)
	_play_animation(HelionAnimationMap.TIME_RING_BURST)
	if _barrage_ctrl != null:
		_barrage_ctrl.spawn_celestial_dial_burst(global_position, 20)
		_barrage_ctrl.spawn_astrolabe_shockwave(global_position, 15)


func _enter_purification_required() -> void:
	if attack_timer != null:
		attack_timer.stop()
	_set_attack_state(AttackState.IDLE)
	_set_core_exposed(true)
	_play_animation(HelionAnimationMap.PHASE3_HOLD)


func _enter_defeated() -> void:
	is_hostile = false
	is_battle_active = false

	if attack_timer != null:
		attack_timer.stop()
	_set_attack_state(AttackState.RECOVERY)
	_set_core_exposed(false)

	if body_hurtbox != null:
		body_hurtbox.monitorable = false
	if core_hurtbox != null:
		core_hurtbox.monitorable = false

	if rewind_recorder != null and rewind_recorder.has_method("stop_recording"):
		rewind_recorder.call("stop_recording")

	_play_animation(HelionAnimationMap.RECOVERY)

	var floor_ctrl: Node = _find_floor_controller()
	if floor_ctrl != null and floor_ctrl.has_method("restore_all"):
		floor_ctrl.call("restore_all")

	_emit_audio_cue(&"boss_purified")
	boss_defeated.emit(&"helion")


# ─── ATTACK STATE MACHINE & BARRAGE EXECUTION ───

func _set_attack_state(state: AttackState) -> void:
	current_attack = state
	attack_state_changed.emit(int(state))


func _schedule_next_attack() -> void:
	if not is_battle_active or current_phase == Phase.DEFEATED:
		return
	if current_phase == Phase.PURIFICATION_REQUIRED or current_phase == Phase.PHASE_3_TRANSITION:
		return

	var min_wait: float = config.attack_interval_min if config != null else 2.2
	var max_wait: float = config.attack_interval_max if config != null else 3.8
	var wait := randf_range(min_wait, max_wait)

	if attack_timer != null:
		attack_timer.start(wait)


func _on_attack_timer_timeout() -> void:
	if not is_battle_active or current_phase == Phase.DEFEATED:
		return
	if current_attack != AttackState.IDLE:
		_schedule_next_attack()
		return

	var attack := _pick_next_attack()
	_execute_attack(attack)


func _pick_next_attack() -> AttackState:
	var pool: Array[AttackState] = []
	match current_phase:
		Phase.PHASE_1:
			pool = [AttackState.SWEEP, AttackState.CLOCK_DROP]
		Phase.PHASE_2:
			pool = [AttackState.SWEEP, AttackState.REWIND, AttackState.CLOCK_DROP]
		Phase.PHASE_3:
			pool = [AttackState.RING_BURST, AttackState.SWEEP, AttackState.CLOCK_DROP]

	if pool.is_empty():
		return AttackState.IDLE

	var picked: AttackState = pool[randi() % pool.size()]
	var attempts: int = 0
	while _would_triple(picked) and attempts < 10:
		picked = pool[randi() % pool.size()]
		attempts += 1

	return picked


func _would_triple(attack: AttackState) -> bool:
	if _last_attacks.size() < 2:
		return false
	return _last_attacks[-1] == attack and _last_attacks[-2] == attack


func _execute_attack(attack: AttackState) -> void:
	_last_attacks.append(attack)
	if _last_attacks.size() > 5:
		_last_attacks.pop_front()

	match attack:
		AttackState.SWEEP:
			_execute_sweep()
		AttackState.CLOCK_DROP:
			_execute_clock_drop()
		AttackState.REWIND:
			_execute_rewind()
		AttackState.RING_BURST:
			_execute_ring_burst()


## Pattern A: Clock Drop Bombardment (Heavy Gear Clusters + Fan Bullets)
func _execute_clock_drop() -> void:
	_set_attack_state(AttackState.CLOCK_DROP)
	_find_player()

	if _barrage_ctrl != null:
		var arena_rect := _get_arena_rect()
		var floor_y := arena_rect.position.y + arena_rect.size.y
		var count: int = 2 if current_phase == Phase.PHASE_1 else 3

		# Drop 1 targeting near player, others random
		if _player != null:
			_barrage_ctrl.spawn_heavy_gear_drop(Vector2(_player.global_position.x, floor_y), 0.9, config.clock_mark_damage if config else 14)
			_barrage_ctrl.spawn_aimed_gear_fan(global_position + Vector2(0, -60), _player.global_position, 3, 30.0, 320.0, 10)

		for i in range(count - 1):
			var rx := randf_range(arena_rect.position.x + 80.0, arena_rect.position.x + arena_rect.size.x - 80.0)
			_barrage_ctrl.spawn_heavy_gear_drop(Vector2(rx, floor_y), 1.1 + float(i) * 0.25, config.clock_mark_damage if config else 14)

	_finish_attack_after(2.0)


## Pattern B: Minute Sweep & 12-Hour Burst (Exposes Core for Counter-attack)
func _execute_sweep() -> void:
	_set_attack_state(AttackState.SWEEP)
	_play_animation(HelionAnimationMap.MINUTE_SWEEP)
	_find_player()

	if _barrage_ctrl != null:
		if _player != null:
			_barrage_ctrl.spawn_aimed_gear_fan(global_position + Vector2(0, -50), _player.global_position, 5, 50.0, 360.0, 12)
		if current_phase != Phase.PHASE_1:
			_barrage_ctrl.spawn_12_clock_burst(global_position + Vector2(0, -50), 300.0, 10)

	# Expose core window after sweep
	_set_core_exposed(true)
	var tree := get_tree()
	if tree != null:
		await tree.create_timer(3.2).timeout
	_set_core_exposed(false)
	_on_attack_finished()


## Pattern C: Rewind & Spiral Storm
func _execute_rewind() -> void:
	_set_attack_state(AttackState.REWIND)
	_play_animation(HelionAnimationMap.REWIND_CAST)
	_emit_audio_cue(&"rewind_charge")

	if _barrage_ctrl != null:
		_barrage_ctrl.spawn_spiral_stream(global_position + Vector2(0, -50), 6, 0.09, 10)

	_finish_attack_after(2.2)


## Pattern D: Celestial Dial & Astrolabe Burst
func _execute_ring_burst() -> void:
	_set_attack_state(AttackState.RING_BURST)
	_play_animation(HelionAnimationMap.TIME_RING_BURST)

	if _barrage_ctrl != null:
		_barrage_ctrl.spawn_celestial_dial_burst(global_position + Vector2(0, -60), config.ring_damage if config else 16)
		_barrage_ctrl.spawn_astrolabe_shockwave(global_position + Vector2(0, -20), config.ring_damage - 3 if config else 13)
		_barrage_ctrl.spawn_12_clock_burst(global_position + Vector2(0, -50), 340.0, 12, 15.0)

	_set_core_exposed(true)
	var tree := get_tree()
	if tree != null:
		await tree.create_timer(3.8).timeout
	_set_core_exposed(false)
	_on_attack_finished()


func _finish_attack_after(delay_sec: float) -> void:
	var tree := get_tree()
	if tree != null:
		await tree.create_timer(delay_sec).timeout
	_on_attack_finished()


func _on_attack_finished() -> void:
	_set_attack_state(AttackState.IDLE)
	_play_animation(_get_idle_animation())
	_schedule_next_attack()


func _get_idle_animation() -> StringName:
	match current_phase:
		Phase.PHASE_3, Phase.PURIFICATION_REQUIRED:
			return HelionAnimationMap.PHASE3_HOLD
		_:
			return HelionAnimationMap.IDLE


# ─── DAMAGE & POTION INTERACTION ───

func deal_damage_to_player(amount: int, source_id: StringName = &"helion_attack") -> void:
	if _arena != null and _arena.has_method("apply_damage_to_player"):
		_arena.call("apply_damage_to_player", amount, source_id)
	else:
		var current: Node = self
		while current != null:
			if current.has_method("apply_player_damage"):
				current.call("apply_player_damage", amount, source_id)
				return
			current = current.get_parent()
		var runtime := get_node_or_null("/root/DayRuntime")
		if runtime != null and runtime.has_method("apply_player_damage"):
			runtime.call("apply_player_damage", amount, source_id)


func receive_potion_hit(hit: Dictionary) -> void:
	if not is_hostile or current_phase == Phase.DEFEATED:
		return

	if not is_battle_active:
		begin_battle()
		if _arena != null and _arena.has_method("trigger_boss_battle"):
			_arena.call("trigger_boss_battle")

	var base_damage: float = float(hit.get("damage", 30))
	var potion_name_str := str(hit.get("potion_id", "")).to_lower()
	var is_purify := PotionCapabilityResolver.hit_has_capability(hit, &"purify_strong") or PotionCapabilityResolver.hit_has_capability(hit, &"purify") or potion_name_str.contains("purif")
	var is_explosive := PotionCapabilityResolver.hit_has_capability(hit, &"impact") or PotionCapabilityResolver.hit_has_capability(hit, &"fire")
	var is_ice := PotionCapabilityResolver.hit_has_capability(hit, &"freeze")

	# Multipliers
	var mult: float = 1.0
	if is_core_exposed:
		mult = 2.5
	else:
		mult = 0.5

	if is_explosive:
		mult *= 1.4
	if is_purify:
		mult *= 1.8

	if is_ice:
		# Ice chills boss and pauses attack timer briefly
		if attack_timer != null and not attack_timer.is_stopped():
			attack_timer.start(attack_timer.time_left + 1.5)

	var final_damage := maxi(5, roundi(base_damage * mult))

	if is_purify and (current_hp <= 100 or current_phase == Phase.PURIFICATION_REQUIRED):
		_purify_hit_received = true
		_set_phase(Phase.DEFEATED)
		return

	_apply_boss_damage(final_damage)

	if _hit_feedback != null and _hit_feedback.has_method("play_hit"):
		_hit_feedback.call("play_hit")

	_emit_audio_cue(&"boss_hit")


func _apply_boss_damage(amount: int) -> void:
	if current_phase == Phase.DEFEATED:
		return

	var min_hp: int = 1 if (config != null and config.final_purify_required) else 0
	current_hp = maxi(min_hp, current_hp - amount)
	health_changed.emit(current_hp, config.max_hp if config else 2000)
	_check_phase_transition()


func _set_core_exposed(exposed: bool) -> void:
	if is_core_exposed == exposed:
		return
	is_core_exposed = exposed
	core_exposed.emit(exposed)

	if core_hurtbox != null:
		core_hurtbox.monitorable = exposed
		core_hurtbox.monitoring = exposed

	if core_glow != null:
		var target_alpha: float = 1.0 if exposed else 0.3
		var tween := create_tween()
		if tween != null:
			tween.tween_property(core_glow, "modulate:a", target_alpha, 0.3)

	if exposed:
		_emit_audio_cue(&"boss_break")


# ─── ANIMATION & CUE DISPATCH ───

func _play_animation(anim_name: StringName) -> void:
	if sprite != null and sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)


func _on_sprite_frame_changed() -> void:
	if cues_resource == null or sprite == null:
		return
	var anim_name: StringName = sprite.animation
	var local_frame: int = sprite.frame
	var active_cues: Array[StringName] = cues_resource.get_cues_at(anim_name, local_frame)
	for cue_id: StringName in active_cues:
		_dispatch_cue(cue_id)


func _dispatch_cue(cue_id: StringName) -> void:
	match cue_id:
		&"core_expose":
			_set_core_exposed(true)
		&"core_close":
			_set_core_exposed(false)
		&"boss_break":
			_emit_audio_cue(&"boss_break")


func _on_animation_finished() -> void:
	if sprite == null:
		return
	var anim_name: StringName = sprite.animation
	if anim_name == HelionAnimationMap.RECOVERY:
		_play_animation(HelionAnimationMap.PURIFIED_IDLE)
	elif anim_name == HelionAnimationMap.PHASE3_TRANSFORM:
		_set_phase(Phase.PHASE_3)
		_set_attack_state(AttackState.IDLE)
		_play_animation(HelionAnimationMap.PHASE3_HOLD)
		_schedule_next_attack()


func _find_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if is_inside_tree() and get_tree() != null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			var inside := get_tree().get_first_node_in_group("clocktower_inside")
			if inside != null:
				_player = inside.get_node_or_null("Player") as Node2D
		if _player == null and get_tree().current_scene != null:
			_player = get_tree().current_scene.find_child("Player", true, false) as Node2D


func _get_arena_rect() -> Rect2:
	if _arena != null and _arena.has_method("get_arena_rect"):
		return _arena.call("get_arena_rect")
	return Rect2(global_position.x - 600.0, global_position.y - 400.0, 1200.0, 500.0)


func _find_floor_controller() -> Node:
	if _arena != null:
		var fc := _arena.get_node_or_null("ClockFloor")
		if fc != null:
			return fc
	return null


func _emit_audio_cue(cue_name: StringName) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	var audio := tree.get_first_node_in_group("clocktower_audio")
	if audio != null and audio.has_method("play_cue"):
		audio.call("play_cue", cue_name)

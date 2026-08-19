class_name HelionBoss
extends Node2D
## 十二刻守望者·赫利昂  /  Helion, Warden of the Twelve
##
## Main boss controller with dual state machine (Phase + AttackState),
## animation-cue-driven gameplay, and data-driven configuration.
## Does NOT: switch scenes, modify DayRuntime, control player, save game.

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

var _last_attacks: Array[AttackState] = []
var _phase3_transform_played: bool = false
var _final_sequence_started: bool = false
var _purify_hit_received: bool = false
var _hit_count_since_sweep: int = 0

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
	if config != null:
		current_hp = config.max_hp

	# Connect sprite frame changes for cue dispatch
	if sprite != null:
		sprite.frame_changed.connect(_on_sprite_frame_changed)
		sprite.animation_finished.connect(_on_animation_finished)

	# Connect attack timer
	if attack_timer != null:
		attack_timer.one_shot = true
		attack_timer.timeout.connect(_on_attack_timer_timeout)

	# Core hurtbox starts disabled
	if core_hurtbox != null:
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


# ═══════════════════════════════════════════════════════════════════
#  PHASE STATE MACHINE
# ═══════════════════════════════════════════════════════════════════

func _set_phase(new_phase: Phase) -> void:
	if current_phase == new_phase:
		return
	var old := current_phase
	current_phase = new_phase
	phase_changed.emit(int(new_phase))

	match new_phase:
		Phase.PHASE_1:
			pass
		Phase.PHASE_2:
			# Start recording player for rewind
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

	match current_phase:
		Phase.PHASE_1:
			if hp_ratio <= config.phase2_threshold:
				_set_phase(Phase.PHASE_2)
		Phase.PHASE_2:
			if hp_ratio <= config.phase3_threshold:
				_set_phase(Phase.PHASE_3_TRANSITION)
		Phase.PHASE_3:
			if not _final_sequence_started and hp_ratio <= config.final_sequence_threshold:
				_begin_final_sequence()
			if config.final_purify_required and current_hp <= 1:
				_set_phase(Phase.PURIFICATION_REQUIRED)
			elif not config.final_purify_required and current_hp <= 0:
				_set_phase(Phase.DEFEATED)


func _begin_phase3_transition() -> void:
	if _phase3_transform_played:
		_set_phase(Phase.PHASE_3)
		return

	_set_attack_state(AttackState.TRANSFORM)
	_play_animation(HelionAnimationMap.PHASE3_TRANSFORM)
	_emit_audio_cue(&"phase3_transform")


func _begin_final_sequence() -> void:
	_final_sequence_started = true
	# Pause normal attacks and run twelve tolls via floor controller
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
	# After final tolls, play time_ring_burst and fully expose core
	_set_attack_state(AttackState.RING_BURST)
	_play_animation(HelionAnimationMap.TIME_RING_BURST)


func _enter_purification_required() -> void:
	# Stop most attacks, expose core permanently
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

	# Disable all hurtboxes
	if body_hurtbox != null:
		body_hurtbox.monitorable = false
	if core_hurtbox != null:
		core_hurtbox.monitorable = false

	# Stop rewind recorder
	if rewind_recorder != null and rewind_recorder.has_method("stop_recording"):
		rewind_recorder.call("stop_recording")

	# Play recovery animation, then purified_idle
	_play_animation(HelionAnimationMap.RECOVERY)
	# animation_finished will transition to purified_idle

	# Restore floor
	var floor_ctrl: Node = _find_floor_controller()
	if floor_ctrl != null and floor_ctrl.has_method("restore_all"):
		floor_ctrl.call("restore_all")

	_emit_audio_cue(&"boss_purified")

	# Signal (delayed to allow recovery animation to start)
	boss_defeated.emit(&"helion")


# ═══════════════════════════════════════════════════════════════════
#  ATTACK STATE MACHINE
# ═══════════════════════════════════════════════════════════════════

func _set_attack_state(state: AttackState) -> void:
	current_attack = state
	attack_state_changed.emit(int(state))


func _schedule_next_attack() -> void:
	if not is_battle_active or current_phase == Phase.DEFEATED:
		return
	if current_phase == Phase.PURIFICATION_REQUIRED:
		return
	if current_phase == Phase.PHASE_3_TRANSITION:
		return

	if config == null:
		return
	var wait: float = randf_range(config.attack_interval_min, config.attack_interval_max)
	if attack_timer != null:
		attack_timer.start(wait)


func _on_attack_timer_timeout() -> void:
	if not is_battle_active:
		return
	if current_attack != AttackState.IDLE:
		# Still in an attack, reschedule
		_schedule_next_attack()
		return

	var attack := _pick_next_attack()
	_execute_attack(attack)


func _pick_next_attack() -> AttackState:
	var pool: Array[AttackState] = []
	match current_phase:
		Phase.PHASE_1:
			pool = [AttackState.SWEEP, AttackState.CLOCK_DROP]
			# Add clock bird spawning separately (not an attack state)
		Phase.PHASE_2:
			pool = [AttackState.SWEEP, AttackState.REWIND, AttackState.CLOCK_DROP]
		Phase.PHASE_3:
			pool = [AttackState.RING_BURST, AttackState.SWEEP, AttackState.CLOCK_DROP]

	if pool.is_empty():
		return AttackState.IDLE

	# Prevent 3 consecutive same attacks
	var picked: AttackState = pool.pick_random()
	var attempts: int = 0
	while _would_triple(picked) and attempts < 10:
		picked = pool.pick_random()
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


func _execute_sweep() -> void:
	_set_attack_state(AttackState.SWEEP)
	_play_animation(HelionAnimationMap.MINUTE_SWEEP)


func _execute_clock_drop() -> void:
	_set_attack_state(AttackState.CLOCK_DROP)
	# Keep idle animation, spawn drops via sector warning
	var warning_node := projectile_root.get_node_or_null("ClockSectorWarning") as Node
	if warning_node == null:
		# Try finding it elsewhere
		warning_node = get_node_or_null("AttackRoot/ProjectileRoot/ClockSectorWarning")

	if warning_node != null and warning_node.has_method("execute_random_drops"):
		var count: int = 2 if current_phase == Phase.PHASE_1 else 3
		var arena_rect := _get_arena_rect()
		var dmg: int = config.clock_mark_damage if config else 12
		warning_node.call("execute_random_drops", count, arena_rect, dmg)
		if warning_node.has_signal("drops_finished"):
			if not warning_node.is_connected("drops_finished", _on_attack_finished):
				warning_node.connect("drops_finished", _on_attack_finished, CONNECT_ONE_SHOT)
	else:
		# No warning node, just finish
		_on_attack_finished()


func _execute_rewind() -> void:
	_set_attack_state(AttackState.REWIND)
	_play_animation(HelionAnimationMap.REWIND_CAST)
	_emit_audio_cue(&"rewind_charge")


func _execute_ring_burst() -> void:
	_set_attack_state(AttackState.RING_BURST)
	_play_animation(HelionAnimationMap.TIME_RING_BURST)


func _on_attack_finished() -> void:
	_set_attack_state(AttackState.IDLE)
	if current_phase == Phase.PHASE_3 or current_phase == Phase.PHASE_2 or current_phase == Phase.PHASE_1:
		_play_animation(_get_idle_animation())
	_schedule_next_attack()


func _get_idle_animation() -> StringName:
	match current_phase:
		Phase.PHASE_3, Phase.PURIFICATION_REQUIRED:
			return HelionAnimationMap.PHASE3_HOLD
		_:
			return HelionAnimationMap.IDLE


# ═══════════════════════════════════════════════════════════════════
#  ANIMATION CUE DISPATCH
# ═══════════════════════════════════════════════════════════════════

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
		# ── Sweep ──
		&"sweep_warning":
			if sweep_root != null and sweep_root.has_method("show_warning"):
				sweep_root.call("show_warning")
			_emit_audio_cue(&"sweep_warning")

		&"sweep_hitbox_on":
			if sweep_root != null and sweep_root.has_method("activate_hitbox"):
				var direction: int = 1 if randi() % 2 == 0 else -1
				var dmg: int = config.sweep_damage if config else 15
				sweep_root.call("begin_sweep", direction, dmg)
				sweep_root.call("activate_hitbox")
			_emit_audio_cue(&"sweep_release")

		&"sweep_hitbox_off":
			if sweep_root != null and sweep_root.has_method("deactivate_hitbox"):
				sweep_root.call("deactivate_hitbox")

		# ── Core Exposure ──
		&"core_expose":
			_set_core_exposed(true)

		&"core_close":
			_set_core_exposed(false)
			if current_attack == AttackState.SWEEP or current_attack == AttackState.REWIND:
				_on_attack_finished()

		# ── Rewind ──
		&"rewind_fx_begin":
			if rewind_fx_root != null and rewind_fx_root.has_method("begin_distortion"):
				rewind_fx_root.call("begin_distortion")

		&"rewind_target_show":
			_show_rewind_target()

		&"rewind_commit":
			_execute_rewind_commit()
			_emit_audio_cue(&"rewind_commit")

		&"rewind_end":
			if rewind_fx_root != null and rewind_fx_root.has_method("end_distortion"):
				rewind_fx_root.call("end_distortion")

		# ── Phase 3 Transform ──
		&"clock_seals_begin":
			_emit_audio_cue(&"phase3_transform")

		&"phase3_arena_enable":
			var floor_ctrl := _find_floor_controller()
			if floor_ctrl != null and floor_ctrl.has_method("enable_sector_mode"):
				floor_ctrl.call("enable_sector_mode")

		&"phase3_ready":
			_set_phase(Phase.PHASE_3)
			_set_attack_state(AttackState.IDLE)
			_play_animation(HelionAnimationMap.PHASE3_HOLD)
			_schedule_next_attack()

		# ── Ring Burst ──
		&"ring_warning":
			_emit_audio_cue(&"time_ring_warning")

		&"ring_spawn":
			_spawn_time_ring()
			_emit_audio_cue(&"time_ring_release")

		&"ring_peak":
			if ring_fx_root != null and ring_fx_root.has_method("ring_peak"):
				ring_fx_root.call("ring_peak")

		&"ring_damage_end":
			# Ring handles its own damage cutoff via time_ring_fx

		&"ring_finished":
			_set_core_exposed(true)
			if current_attack == AttackState.RING_BURST:
				# Brief exposure window, then close
				if is_inside_tree():
					var tree := get_tree()
					if tree != null:
						tree.create_timer(2.0).timeout.connect(func() -> void:
							if current_phase != Phase.DEFEATED and current_phase != Phase.PURIFICATION_REQUIRED:
								_set_core_exposed(false)
								_on_attack_finished()
						)


func _on_animation_finished() -> void:
	if sprite == null:
		return
	match sprite.animation:
		HelionAnimationMap.MINUTE_SWEEP:
			if current_attack == AttackState.SWEEP:
				if sweep_root != null and sweep_root.has_method("finish"):
					sweep_root.call("finish")
		HelionAnimationMap.REWIND_CAST:
			pass  # core_close cue handles transition
		HelionAnimationMap.PHASE3_TRANSFORM:
			pass  # phase3_ready cue handles transition
		HelionAnimationMap.TIME_RING_BURST:
			pass  # ring_finished cue handles transition
		HelionAnimationMap.RECOVERY:
			_play_animation(HelionAnimationMap.PURIFIED_IDLE)


# ═══════════════════════════════════════════════════════════════════
#  REWIND MECHANIC
# ═══════════════════════════════════════════════════════════════════

func _show_rewind_target() -> void:
	if rewind_recorder == null or not rewind_recorder.has_method("get_position_at"):
		return
	var seconds: float = config.rewind_seconds if config else 2.0
	var target_pos: Vector2 = rewind_recorder.call("get_position_at", seconds)

	if rewind_fx_root != null and rewind_fx_root.has_method("show_target"):
		rewind_fx_root.call("show_target", target_pos)


func _execute_rewind_commit() -> void:
	if rewind_recorder == null or not rewind_recorder.has_method("execute_rewind"):
		return
	var seconds: float = config.rewind_seconds if config else 2.0
	var arena_rect := _get_arena_rect()
	var _result_pos: Vector2 = rewind_recorder.call("execute_rewind", seconds, arena_rect)

	# Flash the afterimage
	if rewind_fx_root != null and rewind_fx_root.has_method("highlight_and_commit"):
		rewind_fx_root.call("highlight_and_commit")

	# Brief rewind safety invulnerability
	_apply_rewind_safety()


func _apply_rewind_safety() -> void:
	_find_player()
	if _player == null:
		return
	# Use the player's existing invulnerability system if available
	var safety_time: float = config.rewind_safety_time if config else 0.20
	if _player.has_method("set_invulnerable"):
		_player.call("set_invulnerable", safety_time)
	elif _player.has_method("apply_iframes"):
		_player.call("apply_iframes", safety_time)
	# If player has no invulnerability API, the 0.2s is short enough to be safe


# ═══════════════════════════════════════════════════════════════════
#  RING BURST
# ═══════════════════════════════════════════════════════════════════

func _spawn_time_ring() -> void:
	if ring_fx_root == null or not ring_fx_root.has_method("spawn_ring"):
		return
	var dmg: int = config.ring_damage if config else 20
	ring_fx_root.call("spawn_ring", global_position, dmg)


# ═══════════════════════════════════════════════════════════════════
#  DAMAGE & POTION INTERFACE
# ═══════════════════════════════════════════════════════════════════

func receive_potion_hit(hit: Dictionary) -> void:
	if current_phase == Phase.DEFEATED:
		return

	var potion_id: String = String(hit.get("potion_id", ""))
	var base_damage: float = float(hit.get("damage", 10))

	# Determine effect tags from potion_id string
	var is_purify: bool = "pure" in potion_id or "purification" in potion_id
	var is_explosive: bool = "red" in potion_id or "bomb" in potion_id or "explo" in potion_id
	var is_ice: bool = "blue" in potion_id or "ice" in potion_id or "cyan" in potion_id

	# Calculate damage multiplier
	var multiplier: float = 1.0
	if config != null:
		multiplier = config.exposed_damage_multiplier if is_core_exposed else config.normal_damage_multiplier
		if is_explosive:
			multiplier *= config.explosive_multiplier
		if is_purify:
			multiplier *= config.purify_multiplier

	var final_damage: int = maxi(1, roundi(base_damage * multiplier))

	# Handle purification requirement
	if current_phase == Phase.PURIFICATION_REQUIRED:
		if is_purify:
			_purify_hit_received = true
			_set_phase(Phase.DEFEATED)
			return
		else:
			# Non-purify hits in purification phase do minimal chip damage
			final_damage = 1

	# Apply damage
	_apply_boss_damage(final_damage)

	# Hit feedback
	if _hit_feedback != null and _hit_feedback.has_method("play_hit"):
		if config != null:
			_hit_feedback.call("play_hit",
				config.hit_recoil_min_px,
				config.hit_recoil_max_px,
				config.hit_flash_duration,
				config.hit_recoil_return_time)
		else:
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

	# Visual feedback on core glow
	if core_glow != null:
		var target_alpha: float = 1.0 if exposed else 0.3
		var tween := create_tween()
		if tween != null:
			tween.tween_property(core_glow, "modulate:a", target_alpha, 0.3)

	if exposed:
		_emit_audio_cue(&"boss_break")


# ═══════════════════════════════════════════════════════════════════
#  FLOOR SECTOR INTEGRATION (Phase 3)
# ═══════════════════════════════════════════════════════════════════

func _execute_floor_retract() -> void:
	var floor_ctrl := _find_floor_controller()
	if floor_ctrl == null:
		return

	# Cycle through round types
	var round_methods: Array[String] = ["execute_round_1", "execute_round_2", "execute_round_3"]
	var method: String = round_methods[_hit_count_since_sweep % round_methods.size()]
	_hit_count_since_sweep += 1

	var warn_time: float = config.sector_warning_time if config else 1.2
	var retract_time: float = config.sector_retract_time if config else 1.4

	if floor_ctrl.has_method(method):
		floor_ctrl.call(method, warn_time, retract_time)


# ═══════════════════════════════════════════════════════════════════
#  UTILITY
# ═══════════════════════════════════════════════════════════════════

func _play_animation(anim_name: StringName) -> void:
	if sprite != null and sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)


func _find_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			_player = tree.get_first_node_in_group("player") as Node2D
	if _player == null:
		# Fallback: try finding Player node in parent hierarchy
		var p: Node = get_parent()
		while p != null:
			var found := p.get_node_or_null("Player")
			if found is Node2D:
				_player = found as Node2D
				break
			p = p.get_parent()


func _find_floor_controller() -> Node:
	if _arena != null:
		var ctrl := _arena.get_node_or_null("ClockFloor")
		if ctrl != null:
			return ctrl
	# Search upward
	var p: Node = get_parent()
	while p != null:
		var ctrl := p.get_node_or_null("ClockFloor")
		if ctrl != null:
			return ctrl
		p = p.get_parent()
	return null


func _get_arena_rect() -> Rect2:
	if _arena != null and _arena.has_method("get_arena_rect"):
		return _arena.call("get_arena_rect") as Rect2
	# Fallback
	return Rect2(-600, -800, 1200, 800)


func set_arena(arena_node: Node2D) -> void:
	_arena = arena_node


func _emit_audio_cue(cue_name: StringName) -> void:
	if audio_root == null:
		return
	# Try calling a play method on audio root
	var method_name: String = "play_" + String(cue_name)
	if audio_root.has_method(method_name):
		audio_root.call(method_name)
	# Also try via group
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method(method_name):
				audio.call(method_name)
	# Silent if no audio found — no errors


func _process(_delta: float) -> void:
	# Update rewind target position display during rewind cast
	if current_attack == AttackState.REWIND and rewind_fx_root != null:
		if rewind_recorder != null and rewind_recorder.has_method("get_position_at"):
			var seconds: float = config.rewind_seconds if config else 2.0
			var pos: Vector2 = rewind_recorder.call("get_position_at", seconds)
			if rewind_fx_root.has_method("update_target"):
				rewind_fx_root.call("update_target", pos)

	# Phase 3: periodically trigger floor retracts during phase3_hold
	if current_phase == Phase.PHASE_3 and current_attack == AttackState.IDLE:
		if not _final_sequence_started:
			# Floor retract is handled by attack scheduler via CLOCK_DROP
			pass

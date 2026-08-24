class_name VesperDirectorBoss
extends CharacterBody2D

## Vespervale Hospital Director Boss AI.
## Theme: Distorted therapy, lantern sweeps, sedative throws, dream grasps, deep dream burst, moon shield.

signal health_changed(current_hp: float, max_hp: float)
signal phase_changed(new_phase: int)
signal dream_tide_state_changed(is_tide: bool)
signal boss_defeated

enum Phase {
	PHASE1_WARD_PATROL = 1, # 100% -> 70%
	PHASE2_DEEP_DREAM = 2,  # 70% -> 35%
	PHASE3_TREATMENT_END = 3 # 35% -> 0%
}

enum BossState {
	INTRO,
	IDLE,
	ATTACK_SELECT,
	LANTERN_SWEEP,
	THROW_POTION,
	SUMMON_HANDS,
	CAST_BALL,
	CAST_SOUL_FIRE,
	CAST_CRESCENT,
	BURST,
	RECOVERY,
	DEFEATED
}

# Prefabs for projectiles and hazards
const PREFAB_POTION := preload("res://day/levels/Vespervale/boss/tranquilizer_potion.tscn")
const PREFAB_HANDS := preload("res://day/levels/Vespervale/boss/dream_hand_circle.tscn")
const PREFAB_BALL := preload("res://day/levels/Vespervale/boss/moon_orb_bullet.tscn")
const PREFAB_SOUL_FIRE := preload("res://day/levels/Vespervale/boss/soul_fire_bullet.tscn")
const PREFAB_CRESCENT := preload("res://day/levels/Vespervale/boss/crescent_wave_bullet.tscn")

@export var max_hp: float = 180.0
@export var current_hp: float = 180.0
@export var move_speed: float = 125.0
@export var min_patrol_x: float = 400.0
@export var max_patrol_x: float = 1520.0
@export var preferred_distance: float = 280.0
@export var min_distance: float = 160.0
@export var dream_tide_cycle: float = 6.0
@export var dream_tide_duration: float = 2.8
@export var lucid_window_duration: float = 3.0

var current_phase: Phase = Phase.PHASE1_WARD_PATROL
var current_state: BossState = BossState.INTRO
var is_active: bool = false
var is_dream_tide: bool = false
var is_shield_active: bool = false
var is_lucid_window: bool = false
var is_dead: bool = false

var _tide_timer: float = 0.0
var _state_timer: float = 0.0
var _idle_delay: float = 1.4
var _last_attack: BossState = BossState.IDLE
var _target_player: Node2D = null

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shield_sprite: Sprite2D = $ShieldFX
@onready var cast_point: Marker2D = $CastPoint
@onready var hurtbox: Area2D = $Hurtbox
@onready var lantern_sweep_area: Area2D = $LanternSweepArea
@onready var sweep_visual: Polygon2D = $LanternSweepArea/SweepVisual


func _ready() -> void:
	current_hp = max_hp
	add_to_group("potion_target")
	add_to_group("boss")

	if anim_sprite != null:
		anim_sprite.animation_finished.connect(_on_animation_finished)
		anim_sprite.play("idle_charge")

	if shield_sprite != null:
		shield_sprite.visible = false

	if lantern_sweep_area != null:
		lantern_sweep_area.monitoring = false
		if sweep_visual != null:
			sweep_visual.visible = false

	_tide_timer = dream_tide_cycle


func start_battle() -> void:
	is_active = true
	_enter_idle()


func _physics_process(delta: float) -> void:
	if not is_active or is_dead:
		_find_player()
		_update_facing()
		return

	_find_player()
	_update_dream_tide_cycle(delta)
	_update_facing()
	_update_tracking_movement(delta)

	# State machine timer
	if _state_timer > 0.0:
		_state_timer -= delta
		if _state_timer <= 0.0:
			_on_state_timer_timeout()


func _find_player() -> void:
	if _target_player == null or not is_instance_valid(_target_player):
		var root := get_tree().current_scene
		if root != null:
			_target_player = root.get_node_or_null("Player") as Node2D


func _update_facing() -> void:
	if _target_player != null and is_instance_valid(_target_player):
		var dir := _target_player.global_position.x - global_position.x
		if anim_sprite != null and not is_zero_approx(dir):
			# Sprite asset naturally faces left. When player is to right (dir > 0), flip_h is true.
			anim_sprite.flip_h = dir > 0.0
		if cast_point != null and not is_zero_approx(dir):
			cast_point.position.x = absf(cast_point.position.x) * (1.0 if dir > 0.0 else -1.0)
		if lantern_sweep_area != null and not is_zero_approx(dir):
			lantern_sweep_area.scale.x = -1.0 if dir > 0.0 else 1.0


func _update_tracking_movement(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y += 850.0 * delta
	else:
		velocity.y = 0.0

	# Track player smoothly during IDLE and RECOVERY
	if current_state == BossState.IDLE or current_state == BossState.RECOVERY:
		if _target_player != null and is_instance_valid(_target_player):
			var dist_x := _target_player.global_position.x - global_position.x
			var abs_dist := absf(dist_x)

			if abs_dist > preferred_distance:
				velocity.x = signf(dist_x) * move_speed
			elif abs_dist < min_distance:
				velocity.x = -signf(dist_x) * (move_speed * 0.65)
			else:
				velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, move_speed * 4.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)

	move_and_slide()

	# Clamp to arena activity area (never get trapped in corners)
	global_position.x = clampf(global_position.x, min_patrol_x, max_patrol_x)


func _update_dream_tide_cycle(delta: float) -> void:
	_tide_timer -= delta
	if _tide_timer <= 0.0:
		if not is_dream_tide and not is_lucid_window:
			# Start Dream Tide
			_start_dream_tide()
		elif is_dream_tide:
			# Dream Tide ended -> Enter Lucid Window
			_start_lucid_window()
		elif is_lucid_window:
			# Lucid Window ended -> Return to normal cycle
			_end_lucid_window()


func _start_dream_tide() -> void:
	is_dream_tide = true
	is_lucid_window = false
	is_shield_active = (current_phase >= Phase.PHASE2_DEEP_DREAM)
	_tide_timer = dream_tide_duration

	if shield_sprite != null and is_shield_active:
		shield_sprite.visible = true
		shield_sprite.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(shield_sprite, "modulate:a", 0.9, 0.3)

	dream_tide_state_changed.emit(true)


func _start_lucid_window() -> void:
	is_dream_tide = false
	is_lucid_window = true
	is_shield_active = false
	_tide_timer = lucid_window_duration

	if shield_sprite != null:
		var tw := create_tween()
		tw.tween_property(shield_sprite, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void: shield_sprite.visible = false)

	dream_tide_state_changed.emit(false)


func _end_lucid_window() -> void:
	is_lucid_window = false
	is_dream_tide = false
	_tide_timer = dream_tide_cycle


func _on_state_timer_timeout() -> void:
	match current_state:
		BossState.IDLE:
			_select_next_attack()
		BossState.RECOVERY:
			_enter_idle()


func _enter_idle() -> void:
	current_state = BossState.IDLE
	if anim_sprite != null:
		anim_sprite.play("idle_charge")
	var speed_mult := 0.7 if is_dream_tide else 1.0
	_state_timer = _idle_delay * speed_mult


func _select_next_attack() -> void:
	var available_attacks: Array[BossState] = []

	# Phase 1 attacks
	available_attacks.append(BossState.LANTERN_SWEEP)
	available_attacks.append(BossState.THROW_POTION)
	available_attacks.append(BossState.SUMMON_HANDS)

	# Phase 2 attacks
	if current_phase >= Phase.PHASE2_DEEP_DREAM:
		available_attacks.append(BossState.CAST_BALL)
		available_attacks.append(BossState.CAST_SOUL_FIRE)

	# Phase 3 attacks
	if current_phase >= Phase.PHASE3_TREATMENT_END:
		available_attacks.append(BossState.CAST_CRESCENT)
		available_attacks.append(BossState.BURST)

	# Avoid repeating identical attack immediately if possible
	if available_attacks.size() > 1 and available_attacks.has(_last_attack):
		available_attacks.erase(_last_attack)

	var chosen: BossState = available_attacks.pick_random()
	_last_attack = chosen
	_execute_attack(chosen)


func _execute_attack(attack: BossState) -> void:
	current_state = attack
	match attack:
		BossState.LANTERN_SWEEP:
			_start_lantern_sweep()
		BossState.THROW_POTION:
			_start_throw_potion()
		BossState.SUMMON_HANDS:
			_start_summon_hands()
		BossState.CAST_BALL:
			_start_cast_ball()
		BossState.CAST_SOUL_FIRE:
			_start_cast_soul_fire()
		BossState.CAST_CRESCENT:
			_start_cast_crescent()
		BossState.BURST:
			_start_burst()


# --- Attack 1: Lantern Sweep ---
func _start_lantern_sweep() -> void:
	if anim_sprite != null:
		anim_sprite.play("lantern_sweep")

	# Telegraph sweep area
	if lantern_sweep_area != null and sweep_visual != null:
		sweep_visual.visible = true
		sweep_visual.modulate.a = 0.2
		var tw := create_tween()
		tw.tween_property(sweep_visual, "modulate:a", 0.7, 0.45)
		tw.tween_callback(func() -> void:
			if lantern_sweep_area != null:
				lantern_sweep_area.monitoring = true
				for b in lantern_sweep_area.get_overlapping_bodies():
					if b.name == "Player" or (b.is_in_group("player") and b.name != "Luca"):
						if b.has_method("apply_damage"):
							b.call("apply_damage", 18.0, global_position)
		)
		tw.tween_interval(0.2)
		tw.tween_callback(func() -> void:
			if lantern_sweep_area != null:
				lantern_sweep_area.monitoring = false
			if sweep_visual != null:
				sweep_visual.visible = false
		)


# --- Attack 2: Tranquilizer Potion Throw ---
func _start_throw_potion() -> void:
	if anim_sprite != null:
		anim_sprite.play("tranquilizer_throw")
	var count := 3 if current_phase >= Phase.PHASE2_DEEP_DREAM else 2
	_spawn_potions_staggered(count)


func _spawn_potions_staggered(count: int) -> void:
	var tw := create_tween()
	for i in range(count):
		tw.tween_callback(func() -> void:
			if is_dead:
				return
			var spawn_pos := cast_point.global_position if cast_point != null else global_position
			var target_pos := global_position + Vector2(-300.0 + i * 140.0, 100.0)
			if _target_player != null and is_instance_valid(_target_player):
				target_pos = _target_player.global_position + Vector2((i - 1) * 80.0, 0.0)

			var pot: TranquilizerPotion = PREFAB_POTION.instantiate()
			var container := get_parent().get_node_or_null("BulletLayer")
			if container == null:
				container = get_parent()
			container.add_child(pot)
			pot.launch(spawn_pos, target_pos)
		)
		tw.tween_interval(0.3)


# --- Attack 3: Dream Hands Summon ---
func _start_summon_hands() -> void:
	if anim_sprite != null:
		anim_sprite.play("dream_hands_summon")

	var num_hands := 3 if current_phase >= Phase.PHASE3_TREATMENT_END else 2
	var base_x := _target_player.global_position.x if _target_player != null else global_position.x - 200.0

	var container := get_parent().get_node_or_null("HazardLayer")
	if container == null:
		container = get_parent()

	for i in range(num_hands):
		var hand_pos := Vector2(base_x + (i - (num_hands - 1) * 0.5) * 160.0, 600.0)
		var hand: DreamHandCircle = PREFAB_HANDS.instantiate()
		hand.global_position = hand_pos
		container.add_child(hand)


# --- Attack 4: Moon Orb Bullets (Fan Spread) ---
func _start_cast_ball() -> void:
	if anim_sprite != null:
		anim_sprite.play("idle_charge")

	var bullet_count := 7 if current_phase >= Phase.PHASE3_TREATMENT_END else 5
	var arc_spread := deg_to_rad(65.0)
	var base_dir := Vector2.LEFT if anim_sprite == null or not anim_sprite.flip_h else Vector2.RIGHT
	if _target_player != null and is_instance_valid(_target_player):
		base_dir = (_target_player.global_position - global_position).normalized()

	var container := get_parent().get_node_or_null("BulletLayer")
	if container == null:
		container = get_parent()

	var start_pos := cast_point.global_position if cast_point != null else global_position

	for i in range(bullet_count):
		var angle_offset := -arc_spread * 0.5 + (arc_spread / (bullet_count - 1)) * i
		var dir := base_dir.rotated(angle_offset)
		var ball: MoonOrbBullet = PREFAB_BALL.instantiate()
		container.add_child(ball)
		ball.fire(start_pos, dir, 280.0)

	_finish_cast(0.6)


# --- Attack 5: Soul Fire Tracking ---
func _start_cast_soul_fire() -> void:
	if anim_sprite != null:
		anim_sprite.play("idle_charge")

	var container := get_parent().get_node_or_null("BulletLayer")
	if container == null:
		container = get_parent()

	var count := 3 if current_phase >= Phase.PHASE3_TREATMENT_END else 2
	var start_pos := cast_point.global_position if cast_point != null else global_position

	for i in range(count):
		var init_dir := Vector2(-1.0, -0.6 + i * 0.6).normalized()
		var fire_orb: SoulFireBullet = PREFAB_SOUL_FIRE.instantiate()
		container.add_child(fire_orb)
		fire_orb.fire(start_pos, init_dir, _target_player)

	_finish_cast(0.6)


# --- Attack 6: Crescent Wave Slash ---
func _start_cast_crescent() -> void:
	if anim_sprite != null:
		anim_sprite.play("lantern_sweep")

	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void:
		if is_dead:
			return
		var container := get_parent().get_node_or_null("BulletLayer")
		if container == null:
			container = get_parent()

		var start_pos := cast_point.global_position if cast_point != null else global_position
		var dir := Vector2.LEFT if anim_sprite == null or not anim_sprite.flip_h else Vector2.RIGHT

		var crescent: CrescentWaveBullet = PREFAB_CRESCENT.instantiate()
		container.add_child(crescent)
		crescent.fire(start_pos, dir)
	)


# --- Attack 7: Deep Dream Burst (Phase 3 Ultimate) ---
func _start_burst() -> void:
	if anim_sprite != null:
		anim_sprite.play("deep_dream_burst")

	# Screen shockwave & multi-hazard combo
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(func() -> void:
		if is_dead:
			return
		# Radial ball explosion
		var container := get_parent().get_node_or_null("BulletLayer")
		if container == null:
			container = get_parent()
		var start_pos := cast_point.global_position if cast_point != null else global_position

		for i in range(12):
			var dir := Vector2.RIGHT.rotated(i * TAU / 12.0)
			var ball: MoonOrbBullet = PREFAB_BALL.instantiate()
			container.add_child(ball)
			ball.fire(start_pos, dir, 220.0)

		# Ground hands under player
		_start_summon_hands()
	)


func _finish_cast(delay: float) -> void:
	_state_timer = delay


func _on_animation_finished() -> void:
	if is_dead:
		return
	_enter_recovery()


func _enter_recovery() -> void:
	current_state = BossState.RECOVERY
	if anim_sprite != null:
		anim_sprite.play("recovery_idle")
	_state_timer = 0.8


# --- Potion Interaction & Damage Processing ---
func apply_potion_effect(effect_id: StringName, context: Dictionary = {}) -> void:
	if is_dead:
		return

	var base_dmg := 20.0

	# Potion effect modifiers
	match effect_id:
		&"purify":
			if is_shield_active:
				# Break Moon Shield instantly!
				is_shield_active = false
				if shield_sprite != null:
					shield_sprite.visible = false
				_start_lucid_window()
				base_dmg = 30.0
			else:
				base_dmg = 25.0
		&"explosion", &"attack":
			base_dmg = 22.0
		_:
			base_dmg = 18.0

	# Calculate damage based on dream tide / shield / lucid window
	var final_dmg := base_dmg
	if is_shield_active:
		final_dmg *= 0.3 # 70% reduction
	elif is_lucid_window:
		final_dmg *= 1.3 # 30% bonus vulnerability

	take_damage(final_dmg)


func take_damage(amount: float) -> void:
	if is_dead:
		return

	current_hp = maxf(0.0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)

	# Hurt flash
	if anim_sprite != null:
		var tw := create_tween()
		tw.tween_property(anim_sprite, "modulate", Color(1.8, 0.4, 0.4, 1.0), 0.08)
		tw.tween_property(anim_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)

	_check_phase_transition()

	if current_hp <= 0.0:
		_die()


func _check_phase_transition() -> void:
	var hp_ratio := current_hp / max_hp
	var prev_phase := current_phase

	if hp_ratio <= 0.35 and current_phase < Phase.PHASE3_TREATMENT_END:
		current_phase = Phase.PHASE3_TREATMENT_END
		_idle_delay = 0.9
		phase_changed.emit(3)
	elif hp_ratio <= 0.70 and current_phase < Phase.PHASE2_DEEP_DREAM:
		current_phase = Phase.PHASE2_DEEP_DREAM
		_idle_delay = 1.1
		phase_changed.emit(2)


func _die() -> void:
	is_dead = true
	current_state = BossState.DEFEATED

	if shield_sprite != null:
		shield_sprite.visible = false
	if lantern_sweep_area != null:
		lantern_sweep_area.monitoring = false
	if hurtbox != null:
		hurtbox.monitoring = false

	if anim_sprite != null:
		anim_sprite.play("recovery_idle")
		var tw := create_tween()
		tw.tween_property(anim_sprite, "modulate:a", 0.0, 1.8)
		tw.tween_callback(func() -> void:
			boss_defeated.emit()
		)
	else:
		boss_defeated.emit()

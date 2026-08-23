class_name CrownlandBattleDirector
extends Node
## 战斗调度器 / Crownland Battle Director
##
## Controls:
##  - Phase scheduling (cycles, transitions, dialogue)
##  - All attack implementations (A–E + Stage 3 attacks)
##  - Pillar vulnerability windows
##  - ProjectileRoot / WarningRoot / VFXRoot cleanup
##  - Debug shortcuts (F6–F9, debug build only)
##
## References are set via @export or set_refs() after _ready().

# ─── External References ───
@export var boss_path: NodePath = ^"../Boss"
@export var pillars_path: NodePath = ^"../Pillars"
@export var projectile_root_path: NodePath = ^"../ProjectileRoot"
@export var warning_root_path: NodePath = ^"../WarningRoot"
@export var vfx_root_path: NodePath = ^"../VFXRoot"
@export var hud_path: NodePath = ^"../BossHealthBar"
@export var arena_path: NodePath = ^".."
@export var config: CrownlandBossConfig

# ─── Projectile / FX scenes (assign via Inspector or code) ───
## Textures for fan arrows
@export var tex_arrow: Texture2D           ## 半扇展开箭矢.png
@export var tex_magic_circle: Texture2D    ## 魔法阵.png
@export var tex_pillar_intact: Texture2D   ## 黑魔法柱子.png
@export var tex_pillar_broken: Texture2D   ## 破碎的黑魔法柱子.png
@export var tex_needle: Array[Texture2D] = []  ## 竖向两面针*.png (3 variants)
@export var tex_sword: Texture2D           ## 魔剑右向.png
@export var tex_sword_qi: Texture2D        ## 右向剑气.png
@export var tex_orb_small: Texture2D       ## 左向弹幕小.png
@export var tex_orb_medium: Texture2D      ## 左向弹幕中.png
@export var tex_orb_large: Texture2D       ## 左向弹幕1.png
@export var tex_explosion: Array[Texture2D] = []  ## 爆破帧1–4.png

# ─── State ───
var _boss: CrownlandBoss = null
var _pillars: Node2D = null
var _proj_root: Node2D = null
var _warn_root: Node2D = null
var _vfx_root: Node2D = null
var _hud: Node = null
var _arena: Node2D = null

var _player: Node2D = null
var _arena_rect: Rect2 = Rect2(-600, -800, 1200, 800)

var _is_active: bool = false
var _phase1_cycles: int = 0
var _phase1_min_cycles: int = 4
var _pillars_destroyed: int = 0
var _last_attack: StringName = &""

# Attack scheduling
var _attack_cooldown: float = 0.0
var _in_attack: bool = false
var _waiting_recovery: bool = false

# Phase 2 pillar window
var _pillar_window_active: bool = false
var _pillar_window_timer: float = 0.0

# Phase 1 full-cycle tracking (each attack type must appear once per cycle)
var _cycle_attacks_done: Array[StringName] = []
const PHASE1_ATTACK_SET: Array[StringName] = [&"arrow_fan", &"ground_pillar", &"needle_drop", &"magic_sword", &"tracking_orb"]

# Phase 3 attack pool
const PHASE3_POOL: Array[StringName] = [
	&"black_crown_fan", &"sword_cross", &"tracking_orb_p3", &"needle_rain", &"pillar_combo"
]

# Stage 2 combo pool
const PHASE2_COMBOS: Array[StringName] = [&"combo_a", &"combo_b", &"combo_c"]


func _ready() -> void:
	_boss = get_node_or_null(boss_path) as CrownlandBoss
	_pillars = get_node_or_null(pillars_path) as Node2D
	_proj_root = get_node_or_null(projectile_root_path) as Node2D
	_warn_root = get_node_or_null(warning_root_path) as Node2D
	_vfx_root = get_node_or_null(vfx_root_path) as Node2D
	_hud = get_node_or_null(hud_path)
	_arena = get_node_or_null(arena_path) as Node2D

	if config == null and _boss != null:
		config = _boss.config

	if config != null:
		_phase1_min_cycles = config.phase1_required_cycles

	# Connect boss signals
	if _boss != null:
		if _boss.has_signal("phase_changed"):
			_boss.phase_changed.connect(_on_boss_phase_changed)
		if _boss.has_signal("boss_defeated"):
			_boss.boss_defeated.connect(_on_boss_defeated)

	# Connect pillar signals
	if _pillars != null:
		for child: Node in _pillars.get_children():
			if child is CrownlandMagicPillar:
				(child as CrownlandMagicPillar).pillar_destroyed.connect(_on_pillar_destroyed)


func _process(delta: float) -> void:
	if not _is_active:
		return

	# Debug shortcuts (debug build only)
	if OS.is_debug_build():
		_handle_debug_input()

	# Attack scheduling
	if _in_attack or _waiting_recovery:
		return
	_attack_cooldown -= delta
	if _attack_cooldown <= 0.0:
		_schedule_next_attack()

	# Phase 2 pillar window
	if _pillar_window_active:
		_pillar_window_timer -= delta
		if _pillar_window_timer <= 0.0:
			_end_pillar_window()


# ═══════════════════════════════════════════════════════════════
#  BATTLE START / STOP
# ═══════════════════════════════════════════════════════════════

func begin_battle() -> void:
	_is_active = true
	_phase1_cycles = 0
	_pillars_destroyed = 0
	_last_attack = &""
	_cycle_attacks_done = []
	_in_attack = false
	_waiting_recovery = false
	_attack_cooldown = 1.5   # initial delay
	_find_player()
	if _arena != null and _arena.has_method("get_arena_rect"):
		_arena_rect = _arena.call("get_arena_rect") as Rect2
	# Enable pillars in vulnerable mode only in Phase 2
	_set_pillars_vulnerable(false)


func stop_battle() -> void:
	_is_active = false
	_in_attack = false
	_waiting_recovery = false
	cleanup_all()


func reset_battle() -> void:
	stop_battle()
	_phase1_cycles = 0
	_pillars_destroyed = 0
	_cycle_attacks_done = []
	_last_attack = &""
	# Reset pillar states
	if _pillars != null:
		for child: Node in _pillars.get_children():
			if child.has_method("_ready"):
				pass  # Pillars are re-instanced by arena on full reset


# ═══════════════════════════════════════════════════════════════
#  PHASE CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_boss_phase_changed(new_phase: int) -> void:
	match new_phase:
		CrownlandBoss.Phase.PHASE_1:
			_attack_cooldown = 1.5
		CrownlandBoss.Phase.PHASE_2:
			_attack_cooldown = 2.0
			_set_pillars_vulnerable(true)
		CrownlandBoss.Phase.PHASE_3:
			_attack_cooldown = 1.5
			_set_pillars_vulnerable(false)
		CrownlandBoss.Phase.FINAL_PURIFICATION:
			cleanup_all()
			_show_hud_hint("普通药剂无法彻底终结寄生。")
		CrownlandBoss.Phase.DEFEATED:
			_is_active = false
			cleanup_all()


func _on_boss_defeated(_id: StringName) -> void:
	_is_active = false


func _on_pillar_destroyed(_pillar_id: StringName) -> void:
	_pillars_destroyed += 1
	_update_boss_shield_intensity()
	if _pillars_destroyed >= 4 and _boss != null:
		if _boss.current_phase == CrownlandBoss.Phase.PHASE_2:
			_begin_phase2_to_3_transition()


func _update_boss_shield_intensity() -> void:
	# Visual feedback to HUD about pillar count
	_show_hud_hint(_get_shield_status_text())


func _get_shield_status_text() -> String:
	match 4 - _pillars_destroyed:
		4: return "王权屏障：完整"
		3: return "王权屏障：强烈"
		2: return "王权屏障：不稳定"
		1: return "王权屏障：大量破裂"
		0: return "王权屏障：已崩溃"
	return ""


func _begin_phase2_to_3_transition() -> void:
	_is_active = false
	cleanup_all()
	if _boss != null:
		_boss.enter_phase_2_transition()
	# After transition animation time
	if is_inside_tree():
		await get_tree().create_timer(2.0).timeout
	if _boss != null:
		_boss.enter_phase_3()
	_is_active = true
	_attack_cooldown = 1.5


# ═══════════════════════════════════════════════════════════════
#  ATTACK SCHEDULING
# ═══════════════════════════════════════════════════════════════

func _schedule_next_attack() -> void:
	if _boss == null or not _is_active:
		return
	var phase := _boss.current_phase
	match phase:
		CrownlandBoss.Phase.PHASE_1:
			_pick_phase1_attack()
		CrownlandBoss.Phase.PHASE_2:
			_pick_phase2_attack()
		CrownlandBoss.Phase.PHASE_3:
			_pick_phase3_attack()
		_:
			pass


# ── Phase 1 ──

func _pick_phase1_attack() -> void:
	# Build pool of attacks not yet done this cycle
	var remaining: Array[StringName] = []
	for atk: StringName in PHASE1_ATTACK_SET:
		if not _cycle_attacks_done.has(atk):
			remaining.append(atk)
	if remaining.is_empty():
		# Cycle complete
		_phase1_cycles += 1
		_cycle_attacks_done = []
		if _phase1_cycles >= _phase1_min_cycles:
			_begin_phase1_transition()
			return
		# Restart cycle
		for atk: StringName in PHASE1_ATTACK_SET:
			if not _cycle_attacks_done.has(atk):
				remaining.append(atk)

	# Don't repeat last attack
	var pick: StringName = remaining[randi() % remaining.size()]
	var safety := 0
	while pick == _last_attack and remaining.size() > 1 and safety < 10:
		pick = remaining[randi() % remaining.size()]
		safety += 1

	_cycle_attacks_done.append(pick)
	_last_attack = pick
	_execute_attack(pick)


# ── Phase 2 ──

func _pick_phase2_attack() -> void:
	var combos := PHASE2_COMBOS.duplicate()
	var pick: StringName = combos[randi() % combos.size()]
	var safety := 0
	while pick == _last_attack and combos.size() > 1 and safety < 10:
		pick = combos[randi() % combos.size()]
		safety += 1
	_last_attack = pick
	_execute_attack(pick)


# ── Phase 3 ──

func _pick_phase3_attack() -> void:
	var pool := PHASE3_POOL.duplicate()
	var pick: StringName = pool[randi() % pool.size()]
	var safety := 0
	while pick == _last_attack and pool.size() > 1 and safety < 10:
		pick = pool[randi() % pool.size()]
		safety += 1
	_last_attack = pick
	_execute_attack(pick)


# ═══════════════════════════════════════════════════════════════
#  ATTACK DISPATCH
# ═══════════════════════════════════════════════════════════════

func _execute_attack(attack_id: StringName) -> void:
	_in_attack = true
	match attack_id:
		# Phase 1
		&"arrow_fan":       await _attack_arrow_fan(false)
		&"ground_pillar":   await _attack_ground_pillar()
		&"needle_drop":     await _attack_needle_drop()
		&"magic_sword":     await _attack_magic_sword()
		&"tracking_orb":    await _attack_tracking_orbs()
		# Phase 2 combos
		&"combo_a":         await _combo_a()
		&"combo_b":         await _combo_b()
		&"combo_c":         await _combo_c()
		# Phase 3
		&"black_crown_fan": await _attack_arrow_fan(true)
		&"sword_cross":     await _attack_sword_cross()
		&"tracking_orb_p3": await _attack_tracking_orbs_p3()
		&"needle_rain":     await _attack_needle_rain()
		&"pillar_combo":    await _attack_pillar_combo_p3()
	_in_attack = false
	_start_recovery()


func _start_recovery() -> void:
	_waiting_recovery = true
	var min_r := 0.8 if config == null else config.recovery_window_min
	var max_r := 1.2 if config == null else config.recovery_window_max
	var wait := randf_range(min_r, max_r)
	if _boss != null and _boss.current_phase == CrownlandBoss.Phase.PHASE_2:
		# Pillar vulnerability window
		_start_pillar_window(config.pillar_window_duration if config else 1.8)
	if is_inside_tree():
		await get_tree().create_timer(wait).timeout
	_waiting_recovery = false
	_attack_cooldown = 0.0


# ═══════════════════════════════════════════════════════════════
#  ATTACK A — CROWN ARROW FAN
# ═══════════════════════════════════════════════════════════════

func _attack_arrow_fan(is_stage3: bool) -> void:
	if not _is_active:
		return
	var warn_time := config.arrow_warn_time if config else 0.8
	_spawn_boss_magic_circle(_get_boss_pos())
	await _wait(warn_time)
	if not _is_active:
		return

	var count_min := config.arrow_count_min if config else 7
	var count_max := config.arrow_count_max if config else 11
	var arrow_count := randi_range(count_min, count_max)
	var speed := config.arrow_speed if config else 280.0
	var damage := config.arrow_damage if config else 9
	var rot := config.arrow_second_wave_rotation if config else 12.0

	# Determine player half: fire toward player side
	var player_side_x := _get_player_pos().x
	var boss_x := _get_boss_pos().x

	# First wave: fan toward player half
	_spawn_arrow_fan(_get_boss_pos(), arrow_count, speed, damage, player_side_x < boss_x, 0.0)

	if is_stage3 or _phase1_cycles >= 2:
		# Second wave after brief delay with rotation
		await _wait(0.4)
		if not _is_active:
			return
		_spawn_arrow_fan(_get_boss_pos(), arrow_count, speed, damage, player_side_x < boss_x, rot)

	if is_stage3:
		# Stage 3: third wave leaves safe gap
		await _wait(0.4)
		if not _is_active:
			return
		_spawn_arrow_fan(_get_boss_pos(), arrow_count, speed, damage, player_side_x < boss_x, rot * 2.0)


func _spawn_arrow_fan(
		origin: Vector2,
		count: int,
		speed: float,
		damage: int,
		facing_left: bool,
		extra_rotation_deg: float) -> void:
	var spread := PI * 0.7   # ~126 degree spread
	var base_angle := PI if facing_left else 0.0   # left or right half
	var step := spread / maxf(float(count - 1), 1.0)
	var start_angle := base_angle - spread * 0.5
	for i: int in range(count):
		var angle := start_angle + step * float(i) + deg_to_rad(extra_rotation_deg)
		var dir := Vector2(cos(angle), sin(angle))
		_spawn_arrow(origin + Vector2(randf_range(-10, 10), randf_range(-10, 10)), dir, speed, damage)


func _spawn_arrow(origin: Vector2, dir: Vector2, speed: float, damage: int) -> void:
	var arrow := CrownlandArrowProjectile.new()
	arrow.arrow_texture = tex_arrow
	arrow.offscreen_margin = 300.0
	_proj_root.add_child(arrow)
	arrow.global_position = origin
	arrow.launch(dir, speed, damage)


# ═══════════════════════════════════════════════════════════════
#  ATTACK B — GROUND PILLAR (Stage 1)
# ═══════════════════════════════════════════════════════════════

func _attack_ground_pillar() -> void:
	if not _is_active:
		return
	var count := randi_range(
		config.pillar_count_min if config else 3,
		config.pillar_count_max if config else 5
	)
	var damage := config.pillar_hazard_damage if config else 12
	var warn_time := config.pillar_warn_time if config else 1.0
	var floor_y := _arena_rect.position.y + _arena_rect.size.y   # arena floor Y
	var player_x := _get_player_pos().x

	for i: int in range(count):
		if not _is_active:
			return
		var spawn_x: float
		if i < 2:
			# First two: track player position
			spawn_x = player_x + randf_range(-30, 30)
		else:
			# Later: predict slight movement
			var predict := (player_x - _get_boss_pos().x) * 0.3
			spawn_x = player_x + predict + randf_range(-60, 60)
		# Clamp inside arena
		spawn_x = clampf(spawn_x, _arena_rect.position.x + 60.0, _arena_rect.position.x + _arena_rect.size.x - 60.0)

		var hazard := CrownlandBlackPillarHazard.new()
		hazard.magic_circle_texture = tex_magic_circle
		hazard.pillar_texture = tex_pillar_intact
		_proj_root.add_child(hazard)
		hazard.spawn_at(Vector2(spawn_x, floor_y), damage, warn_time)
		# Stagger spawns
		await _wait(0.25)
		if not _is_active:
			return


# ═══════════════════════════════════════════════════════════════
#  ATTACK C — NEEDLE DROP
# ═══════════════════════════════════════════════════════════════

func _attack_needle_drop() -> void:
	if not _is_active:
		return
	var count := randi_range(
		config.needle_count_min if config else 3,
		config.needle_count_max if config else 5
	)
	var damage := config.needle_damage if config else 9
	var warn_time := config.needle_warn_time if config else 0.7
	var fall_speed := config.needle_speed if config else 900.0
	var linger := config.needle_linger_time if config else 0.25
	var floor_y := _arena_rect.position.y + _arena_rect.size.y
	var arena_width := _arena_rect.size.x
	var player_x := _get_player_pos().x

	# Choose positions ensuring at least one safe gap of 80px
	var positions: Array[float] = _choose_needle_positions(count, arena_width, player_x)
	for pos_x: float in positions:
		var needle := CrownlandNeedleDrop.new()
		if not tex_needle.is_empty():
			needle.needle_textures = tex_needle
		_proj_root.add_child(needle)
		needle.spawn_at(pos_x, floor_y, warn_time, fall_speed, linger, damage)

	# Optional second wave (in later cycles)
	if _phase1_cycles >= 2 or (_boss != null and _boss.current_phase == CrownlandBoss.Phase.PHASE_3):
		await _wait(warn_time + 0.4)
		if not _is_active:
			return
		# Fill one of the gaps from the first wave
		var gap_x := _find_gap_center(positions, arena_width)
		var needle2 := CrownlandNeedleDrop.new()
		if not tex_needle.is_empty():
			needle2.needle_textures = tex_needle
		_proj_root.add_child(needle2)
		needle2.spawn_at(gap_x, floor_y, warn_time * 0.7, fall_speed, linger, damage)


func _choose_needle_positions(count: int, width: float, player_x: float) -> Array[float]:
	var left_x := _arena_rect.position.x
	# Divide arena into slots
	var slot_w := width / float(count + 1)
	var positions: Array[float] = []
	var safe_slot := int((player_x - left_x) / slot_w)
	for i: int in range(count + 1):
		if i == safe_slot:
			continue   # leave player's slot empty (safe zone)
		if positions.size() >= count:
			break
		positions.append(left_x + slot_w * float(i) + randf_range(0, slot_w * 0.5))
	# Pad if too few
	while positions.size() < count:
		positions.append(left_x + randf_range(0, width))
	return positions


func _find_gap_center(positions: Array[float], width: float) -> float:
	if positions.is_empty():
		return _arena_rect.position.x + width * 0.5
	positions.sort()
	var best_gap := 0.0
	var best_x := _arena_rect.position.x + 50.0
	var prev := _arena_rect.position.x
	for px: float in positions:
		var gap := px - prev
		if gap > best_gap:
			best_gap = gap
			best_x = prev + gap * 0.5
		prev = px
	return best_x


# ═══════════════════════════════════════════════════════════════
#  ATTACK D — MAGIC SWORD
# ═══════════════════════════════════════════════════════════════

func _attack_magic_sword() -> void:
	if not _is_active:
		return
	var hover_time := config.sword_hover_time if config else 0.6
	var speed := config.sword_speed if config else 700.0
	var qi_delay := config.sword_qi_delay if config else 0.20
	var qi_speed := config.sword_qi_speed if config else 420.0
	var damage := config.sword_damage if config else 10
	var qi_damage := config.sword_qi_damage if config else 9
	var floor_y := _arena_rect.position.y + _arena_rect.size.y - 80.0

	# Randomly come from left or right
	var from_left := randi() % 2 == 0
	var start_x := _arena_rect.position.x - 80.0 if from_left else _arena_rect.position.x + _arena_rect.size.x + 80.0
	var dir := Vector2.RIGHT if from_left else Vector2.LEFT

	# Hover warning
	var warn_pos := Vector2(start_x, floor_y)
	_spawn_sword_warning(warn_pos, dir)
	await _wait(hover_time)
	if not _is_active:
		return

	# Sword body
	_spawn_sword_projectile(warn_pos, dir, speed, damage, false)
	# Qi follows after delay
	await _wait(qi_delay)
	if not _is_active:
		return
	_spawn_sword_projectile(warn_pos, dir, qi_speed, qi_damage, true)


func _spawn_sword_warning(pos: Vector2, dir: Vector2) -> void:
	var line := Line2D.new()
	line.width = 4.0
	line.default_color = Color(0.5, 0.0, 0.1, 0.6)
	line.add_point(Vector2.ZERO)
	line.add_point(dir * 80.0)
	_warn_root.add_child(line)
	line.global_position = pos
	# Remove warning after sword fires
	if is_inside_tree():
		await get_tree().create_timer(
			(config.sword_hover_time if config else 0.6) + 0.1
		).timeout
	if is_instance_valid(line):
		line.queue_free()


func _spawn_sword_projectile(
		origin: Vector2,
		dir: Vector2,
		speed: float,
		damage: int,
		is_qi: bool) -> void:
	var sword := CrownlandSwordProjectile.new()
	sword.sword_texture = tex_sword
	sword.qi_texture = tex_sword_qi
	sword.is_qi = is_qi
	_proj_root.add_child(sword)
	sword.global_position = origin
	sword.launch(dir, speed, damage)


# ═══════════════════════════════════════════════════════════════
#  ATTACK E — TRACKING ORBS
# ═══════════════════════════════════════════════════════════════

func _attack_tracking_orbs() -> void:
	if not _is_active:
		return
	var boss_pos := _get_boss_pos()
	# Spawn one of each size
	_spawn_orb(boss_pos, CrownlandTrackingOrb.OrbSize.SMALL)
	await _wait(0.3)
	if not _is_active:
		return
	_spawn_orb(boss_pos, CrownlandTrackingOrb.OrbSize.MEDIUM)
	await _wait(0.3)
	if not _is_active:
		return
	_spawn_orb(boss_pos, CrownlandTrackingOrb.OrbSize.LARGE)


func _attack_tracking_orbs_p3() -> void:
	# Phase 3 version: all three at once with slight offset
	var boss_pos := _get_boss_pos()
	_spawn_orb(boss_pos + Vector2(-30, 0), CrownlandTrackingOrb.OrbSize.SMALL)
	_spawn_orb(boss_pos, CrownlandTrackingOrb.OrbSize.MEDIUM)
	_spawn_orb(boss_pos + Vector2(30, 0), CrownlandTrackingOrb.OrbSize.LARGE)


func _spawn_orb(origin: Vector2, size: CrownlandTrackingOrb.OrbSize) -> void:
	var orb := CrownlandTrackingOrb.new()
	orb.texture_small = tex_orb_small
	orb.texture_medium = tex_orb_medium
	orb.texture_large = tex_orb_large
	_proj_root.add_child(orb)
	orb.global_position = origin
	var track_s: float
	var track_sp: float
	var dash_sp: float
	var damage: int
	var dash_del := config.orb_dash_delay if config else 0.15
	match size:
		CrownlandTrackingOrb.OrbSize.SMALL:
			track_s = 0.0; track_sp = 0.0
			dash_sp = config.small_orb_speed if config else 380.0
			damage = config.small_orb_damage if config else 8
		CrownlandTrackingOrb.OrbSize.MEDIUM:
			track_s = config.orb_tracking_medium if config else 0.8
			track_sp = config.medium_orb_speed_track if config else 160.0
			dash_sp = config.medium_orb_speed_dash if config else 340.0
			damage = config.medium_orb_damage if config else 10
		CrownlandTrackingOrb.OrbSize.LARGE:
			track_s = config.orb_tracking_large if config else 1.2
			track_sp = config.large_orb_speed_track if config else 90.0
			dash_sp = config.large_orb_speed_dash if config else 260.0
			damage = config.large_orb_damage if config else 12
		_:
			track_s = 0.0; track_sp = 0.0; dash_sp = 300.0; damage = 8
	orb.launch(size, track_s, track_sp, dash_sp, damage, dash_del, _player)


# ═══════════════════════════════════════════════════════════════
#  PHASE 2 COMBOS
# ═══════════════════════════════════════════════════════════════

## Combo A: magic circle → pillar + arrow fan simultaneously
func _combo_a() -> void:
	if not _is_active:
		return
	# Warning
	_spawn_boss_magic_circle(_get_boss_pos())
	await _wait(0.7)
	if not _is_active:
		return
	# Pillar first
	await _attack_ground_pillar()
	await _wait(0.2)
	if not _is_active:
		return
	# Arrow fan while pillar is up
	await _attack_arrow_fan(false)


## Combo B: needle drop forces movement → orbs lock new position
func _combo_b() -> void:
	if not _is_active:
		return
	await _attack_needle_drop()
	await _wait(0.3)
	if not _is_active:
		return
	await _attack_tracking_orbs()


## Combo C: sword from one side + pillar on the other
func _combo_c() -> void:
	if not _is_active:
		return
	# Sword comes from left
	var hover := config.sword_hover_time if config else 0.6
	var speed := config.sword_speed if config else 700.0
	var floor_y := _arena_rect.position.y + _arena_rect.size.y - 80.0
	var start_x := _arena_rect.position.x - 80.0
	var dir := Vector2.RIGHT
	_spawn_sword_warning(Vector2(start_x, floor_y), dir)
	# Pillar on the right side at the same time
	var pillar_x := _arena_rect.position.x + _arena_rect.size.x * 0.7
	var hazard := CrownlandBlackPillarHazard.new()
	hazard.magic_circle_texture = tex_magic_circle
	hazard.pillar_texture = tex_pillar_intact
	_proj_root.add_child(hazard)
	hazard.spawn_at(
		Vector2(pillar_x, _arena_rect.position.y + _arena_rect.size.y),
		config.pillar_hazard_damage if config else 12,
		hover
	)
	await _wait(hover)
	if not _is_active:
		return
	_spawn_sword_projectile(Vector2(start_x, floor_y), dir, speed, config.sword_damage if config else 10, false)
	await _wait(config.sword_qi_delay if config else 0.2)
	if not _is_active:
		return
	_spawn_sword_projectile(Vector2(start_x, floor_y), dir, config.sword_qi_speed if config else 420.0, config.sword_qi_damage if config else 9, true)


# ═══════════════════════════════════════════════════════════════
#  PHASE 3 ATTACKS
# ═══════════════════════════════════════════════════════════════

## Stage 3 needle rain: 3 waves, last targets current player pos
func _attack_needle_rain() -> void:
	if not _is_active:
		return
	var warn := config.needle_warn_time if config else 0.7
	var fall_speed := config.needle_speed if config else 900.0
	var linger := config.needle_linger_time if config else 0.25
	var damage := config.needle_damage if config else 9
	var floor_y := _arena_rect.position.y + _arena_rect.size.y
	var width := _arena_rect.size.x
	var player_x := _get_player_pos().x

	# Wave 1: 50-65% coverage
	var positions1 := _choose_needle_positions(4, width, player_x)
	for px: float in positions1:
		var n := CrownlandNeedleDrop.new()
		if not tex_needle.is_empty():
			n.needle_textures = tex_needle
		_proj_root.add_child(n)
		n.spawn_at(px, floor_y, warn, fall_speed, linger, damage)
	await _wait(warn + 0.3)
	if not _is_active:
		return
	player_x = _get_player_pos().x

	# Wave 2
	var positions2 := _choose_needle_positions(4, width, player_x)
	for px: float in positions2:
		var n := CrownlandNeedleDrop.new()
		if not tex_needle.is_empty():
			n.needle_textures = tex_needle
		_proj_root.add_child(n)
		n.spawn_at(px, floor_y, warn, fall_speed, linger, damage)
	await _wait(warn + 0.2)
	if not _is_active:
		return
	player_x = _get_player_pos().x

	# Wave 3: gap-filling based on player's current position
	var gap_x := _find_gap_center(positions2, width)
	# Intentionally place near gap where player fled
	var n3 := CrownlandNeedleDrop.new()
	if not tex_needle.is_empty():
		n3.needle_textures = tex_needle
	_proj_root.add_child(n3)
	n3.spawn_at(gap_x + randf_range(-40, 40), floor_y, warn * 0.8, fall_speed, linger, damage)


## Stage 3 sword cross: left+right alternating with height variation
func _attack_sword_cross() -> void:
	if not _is_active:
		return
	var speed := config.sword_speed if config else 700.0
	var qi_delay := config.sword_qi_delay if config else 0.2
	var qi_speed := config.sword_qi_speed if config else 420.0
	var damage := config.sword_damage if config else 10
	var qi_dmg := config.sword_qi_damage if config else 9
	var floor_y := _arena_rect.position.y + _arena_rect.size.y
	var left_x := _arena_rect.position.x - 80.0
	var right_x := _arena_rect.position.x + _arena_rect.size.x + 80.0
	var hover := config.sword_hover_time if config else 0.6

	# Pass 1: left→right
	var y1 := floor_y - 80.0
	_spawn_sword_warning(Vector2(left_x, y1), Vector2.RIGHT)
	await _wait(hover)
	if not _is_active:
		return
	_spawn_sword_projectile(Vector2(left_x, y1), Vector2.RIGHT, speed, damage, false)
	await _wait(qi_delay)
	if not _is_active:
		return
	_spawn_sword_projectile(Vector2(left_x, y1), Vector2.RIGHT, qi_speed, qi_dmg, true)
	await _wait(0.4)
	if not _is_active:
		return

	# Pass 2: right→left
	var y2 := floor_y - 120.0
	_spawn_sword_warning(Vector2(right_x, y2), Vector2.LEFT)
	await _wait(hover)
	if not _is_active:
		return
	_spawn_sword_projectile(Vector2(right_x, y2), Vector2.LEFT, speed, damage, false)
	await _wait(qi_delay)
	if not _is_active:
		return
	_spawn_sword_projectile(Vector2(right_x, y2), Vector2.LEFT, qi_speed, qi_dmg, true)
	await _wait(0.4)
	if not _is_active:
		return

	# Pass 3: left→right at different height
	var y3 := floor_y - 220.0   # higher — player must jump or duck
	_spawn_sword_warning(Vector2(left_x, y3), Vector2.RIGHT)
	await _wait(hover * 0.7)
	if not _is_active:
		return
	_spawn_sword_projectile(Vector2(left_x, y3), Vector2.RIGHT, speed, damage, false)


## Stage 3 black sun: large orb, track 1s → stop 0.15s → dash → explosion
func _attack_pillar_combo_p3() -> void:
	if not _is_active:
		return
	# Use large orb as the "black sun"
	var boss_pos := _get_boss_pos()
	_spawn_orb(boss_pos, CrownlandTrackingOrb.OrbSize.LARGE)
	await _wait(
		(config.orb_tracking_large if config else 1.2) +
		(config.orb_dash_delay if config else 0.15) + 0.5
	)
	if not _is_active:
		return
	# Spawn explosion at player's (approximate) landing location
	_spawn_explosion_at(_get_player_pos())


func _spawn_explosion_at(pos: Vector2) -> void:
	# Visual
	if not tex_explosion.is_empty():
		var fx := CrownlandExplosionFx.new()
		fx.frame_textures = tex_explosion
		fx.scale_factor = 1.5
		_vfx_root.add_child(fx)
		fx.global_position = pos
	# Damage area — brief Area2D
	var blast := Area2D.new()
	blast.collision_layer = 0
	blast.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = config.explosion_blast_radius if config else 90.0
	shape.shape = circle
	blast.add_child(shape)
	_proj_root.add_child(blast)
	blast.global_position = pos
	blast.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player") or body.name == "Player":
			_walk_damage_to_player(config.explosion_damage if config else 15)
	)
	if is_inside_tree():
		await get_tree().create_timer(0.3).timeout
	if is_instance_valid(blast):
		blast.queue_free()


# ═══════════════════════════════════════════════════════════════
#  PHASE 1 → 2 TRANSITION
# ═══════════════════════════════════════════════════════════════

func _begin_phase1_transition() -> void:
	_is_active = false
	cleanup_all()
	if _boss != null:
		_boss.enter_phase_1_transition()

	_show_hud_hint("")
	await _wait(2.0)

	# Dialogue sequence
	_show_hud_hint("雪莉: ……还是伤不到他。")
	await _wait(2.5)
	_show_hud_hint("卢卡: 看那些黑柱。")
	await _wait(2.0)
	_show_hud_hint("卢卡: 伤势并非消失。")
	await _wait(2.0)
	_show_hud_hint("卢卡: 是有人在替他承受。")
	await _wait(2.5)
	_show_hud_hint("")

	if _boss != null:
		_boss.enter_phase_2()
	_is_active = true
	_attack_cooldown = 1.5


# ═══════════════════════════════════════════════════════════════
#  PILLAR WINDOW MANAGEMENT
# ═══════════════════════════════════════════════════════════════

func _start_pillar_window(duration: float) -> void:
	_pillar_window_active = true
	_pillar_window_timer = duration
	_show_hud_hint("黑柱正在发光！")
	_set_pillar_highlight(true)
	_set_pillars_vulnerable(true)


func _end_pillar_window() -> void:
	_pillar_window_active = false
	_set_pillar_highlight(false)
	_set_pillars_vulnerable(false)
	_show_hud_hint("")


func _set_pillar_highlight(on: bool) -> void:
	if _pillars == null:
		return
	for child: Node in _pillars.get_children():
		if child is CrownlandMagicPillar:
			var tween := (child as Node2D).create_tween()
			if tween != null:
				var col := Color(1.3, 0.8, 0.8, 1.0) if on else Color.WHITE
				tween.tween_property(child, "modulate", col, 0.3)


func _set_pillars_vulnerable(v: bool) -> void:
	if _pillars == null:
		return
	for child: Node in _pillars.get_children():
		if child is CrownlandMagicPillar:
			(child as CrownlandMagicPillar).set_vulnerable(v)


# ═══════════════════════════════════════════════════════════════
#  CLEANUP
# ═══════════════════════════════════════════════════════════════

func cleanup_all() -> void:
	_cleanup_root(_proj_root)
	_cleanup_root(_warn_root)
	_cleanup_root(_vfx_root)


func _cleanup_root(root: Node2D) -> void:
	if root == null:
		return
	for child: Node in root.get_children():
		if child.has_method("cleanup"):
			child.call("cleanup")
		else:
			child.queue_free()


# ═══════════════════════════════════════════════════════════════
#  UTILITIES
# ═══════════════════════════════════════════════════════════════

func _wait(seconds: float) -> void:
	if is_inside_tree():
		await get_tree().create_timer(seconds).timeout


func _get_boss_pos() -> Vector2:
	if _boss != null:
		return _boss.get_attack_origin()
	return Vector2.ZERO


func _get_player_pos() -> Vector2:
	_find_player()
	if _player != null and is_instance_valid(_player):
		return _player.global_position
	# Fallback: random arena position
	return _arena_rect.get_center() + Vector2(randf_range(-200, 200), 0)


func _find_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if is_inside_tree() and get_tree() != null:
		_player = get_tree().get_first_node_in_group("player") as Node2D


func _walk_damage_to_player(amount: int) -> void:
	var node: Node = self
	while node != null:
		if node.has_method("apply_player_damage"):
			node.call("apply_player_damage", amount, self)
			return
		if node.has_method("apply_fall_or_hazard_damage"):
			node.call("apply_fall_or_hazard_damage", amount, "crownland_explosion")
			return
		node = node.get_parent()


func _spawn_boss_magic_circle(pos: Vector2) -> void:
	if tex_magic_circle != null:
		var s := Sprite2D.new()
		s.texture = tex_magic_circle
		_warn_root.add_child(s)
		s.global_position = pos
		if is_inside_tree():
			await get_tree().create_timer(1.5).timeout
		if is_instance_valid(s):
			s.queue_free()
	else:
		# Procedural placeholder
		var draw_node := Node2D.new()
		_warn_root.add_child(draw_node)
		draw_node.global_position = pos
		draw_node.set_script(null)   # no script — rely on draw call below
		# Actually skip placeholder to avoid complexity without texture


func _show_hud_hint(text: String) -> void:
	if _hud != null:
		if _hud.has_method("show_hint"):
			_hud.call("show_hint", text)
		elif _hud.has_method("set_hint"):
			_hud.call("set_hint", text)
	# Also try arena
	if _arena != null and _arena.has_method("show_hint"):
		_arena.call("show_hint", text)


# ═══════════════════════════════════════════════════════════════
#  DEBUG SHORTCUTS
# ═══════════════════════════════════════════════════════════════

func _handle_debug_input() -> void:
	if Input.is_action_just_pressed("ui_focus_next"):   # placeholder; map to F6
		pass   # mapped via _unhandled_key_input below


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed:
		return
	match key_event.keycode:
		KEY_F6:
			_debug_jump_to_phase(CrownlandBoss.Phase.PHASE_1)
		KEY_F7:
			_debug_jump_to_phase(CrownlandBoss.Phase.PHASE_2)
		KEY_F8:
			_debug_jump_to_phase(CrownlandBoss.Phase.PHASE_3)
		KEY_F9:
			if _boss != null:
				var max_hp := _boss.config.max_hp if _boss.config != null else 100
				_boss.current_hp = maxi(1, int(float(max_hp) * 0.1))
				_boss.health_changed.emit(_boss.current_hp, max_hp)


func _debug_jump_to_phase(phase: CrownlandBoss.Phase) -> void:
	if _boss == null:
		return
	cleanup_all()
	_in_attack = false
	_waiting_recovery = false
	match phase:
		CrownlandBoss.Phase.PHASE_1:
			_boss.reset_battle()
			_boss.begin_battle()
			_phase1_cycles = 0
			_cycle_attacks_done = []
		CrownlandBoss.Phase.PHASE_2:
			_boss.enter_phase_2()
			_set_pillars_vulnerable(true)
		CrownlandBoss.Phase.PHASE_3:
			_boss.enter_phase_3()
	_attack_cooldown = 1.0
	_is_active = true

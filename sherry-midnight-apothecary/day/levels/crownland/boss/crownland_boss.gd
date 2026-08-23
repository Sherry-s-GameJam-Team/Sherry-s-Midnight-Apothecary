class_name CrownlandBoss
extends Node2D
## 被黑魔法寄生的国王 / The King Parasitized by Dark Magic
##
## Boss node responsible for:
##   - Phase state machine (INTRO → PHASE_1 → ... → DEFEATED)
##   - AnimatedSprite2D playback
##   - Hurtbox enable/disable
##   - receive_potion_hit() entry point
##   - Color resistance system (Stage 3)
##   - Shield ripple on Phase 1 hits
##   - Final purification sequence
##
## Does NOT: switch scenes, modify DayRuntime, control player, save game.
## Damage forwarding to player done via parent-walk in BattleDirector / projectile scripts.

# ─── Signals ───
signal health_changed(current_hp: int, max_hp: int)
signal phase_changed(new_phase: int)
signal boss_started
signal boss_defeated(boss_id: StringName)
signal shield_hit   # Phase 1 potion blocked
signal final_purification_started

# ─── Phase Enum ───
enum Phase {
	INTRO,
	PHASE_1,
	PHASE_1_TRANSITION,
	PHASE_2,
	PHASE_2_TRANSITION,
	PHASE_3,
	FINAL_PURIFICATION,
	DEFEATED,
	RESET,
}

# ─── Animation names ───
const ANIM_IDLE         := &"idle"
const ANIM_PHASE1_IDLE  := &"phase1_idle"
const ANIM_PHASE2_IDLE  := &"phase2_idle"
const ANIM_PHASE3_IDLE  := &"phase3_idle"
const ANIM_TRANSITION   := &"transition"
const ANIM_PHASE3_ENTER := &"phase3_enter"
const ANIM_HURT         := &"hurt"
const ANIM_DYING        := &"dying"
const ANIM_PURIFIED     := &"purified"

# ─── Config ───
@export var config: CrownlandBossConfig
@export_group("Phase 2 Presentation")
@export var phase2_float_amplitude: float = 14.0
@export var phase2_float_speed: float = 1.5

# ─── State ───
var current_phase: Phase = Phase.INTRO
var current_hp: int = 100
var is_battle_active: bool = false
var is_invulnerable: bool = true   # always true until Phase 3

# ─── Color resistance (Stage 3) ───
# Maps potion color key → consecutive hit count
var _color_hit_count: Dictionary = {}
var _last_color_key: String = ""
var _color_timer: float = 0.0

# ─── Misc state ───
var _shield_hint_shown: bool = false
var _final_purification_active: bool = false
var _phase2_float_time := 0.0
var _visual_root_base_position := Vector2.ZERO
var _final_shake_remaining := 0.0
var _final_shake_amplitude := 22.0
var _final_white_tween: Tween

# ─── Nodes ───
@onready var _visual_root: Node2D = $VisualRoot
@onready var _sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var _shield_visual: Node2D = $ShieldVisual
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _attack_origin: Marker2D = $AttackOrigin
@onready var _left_origin: Marker2D = $LeftAttackOrigin
@onready var _right_origin: Marker2D = $RightAttackOrigin

var _hit_flash_tween: Tween
var _shield_tween: Tween


func _ready() -> void:
	if _visual_root != null:
		_visual_root_base_position = _visual_root.position
	if config != null:
		current_hp = config.max_hp
	else:
		current_hp = 100

	# Hurtbox starts disabled — enabled only in Phase 3
	if _hurtbox != null:
		_hurtbox.monitorable = false
		_hurtbox.monitoring = false


func _process(delta: float) -> void:
	if not is_battle_active:
		return
	_update_phase2_float(delta)
	_update_final_defeat_shake(delta)
	# Color resistance decay
	if current_phase == Phase.PHASE_3 and _last_color_key != "":
		_color_timer += delta
		if config != null and _color_timer >= config.resist_reset_time:
			_reset_color_resistance()


# ═══════════════════════════════════════════════════════════════
#  BATTLE LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func begin_battle() -> void:
	is_battle_active = true
	boss_started.emit()
	_set_phase(Phase.PHASE_1)
	_play_animation(ANIM_PHASE1_IDLE)


func reset_battle() -> void:
	is_battle_active = false
	if config != null:
		current_hp = config.max_hp
	else:
		current_hp = 100
	is_invulnerable = true
	_shield_hint_shown = false
	_final_purification_active = false
	_final_shake_remaining = 0.0
	_reset_color_resistance()
	current_phase = Phase.INTRO
	if _hurtbox != null:
		_hurtbox.monitorable = false
		_hurtbox.monitoring = false
	if _visual_root != null:
		_visual_root.modulate = Color.WHITE
		_visual_root.position = _visual_root_base_position
	_play_animation(ANIM_PHASE1_IDLE)


# ═══════════════════════════════════════════════════════════════
#  PHASE STATE MACHINE
# ═══════════════════════════════════════════════════════════════

func _set_phase(new_phase: Phase) -> void:
	if current_phase == new_phase:
		return
	current_phase = new_phase
	if new_phase != Phase.PHASE_2:
		_phase2_float_time = 0.0
		if _visual_root != null:
			_visual_root.position = _visual_root_base_position
	phase_changed.emit(int(new_phase))
	match new_phase:
		Phase.PHASE_1:
			is_invulnerable = true
			_set_hurtbox(false)
		Phase.PHASE_1_TRANSITION:
			is_invulnerable = true
			_set_hurtbox(false)
			_play_animation(ANIM_TRANSITION)
		Phase.PHASE_2:
			is_invulnerable = true
			_set_hurtbox(false)
			_play_animation(ANIM_PHASE2_IDLE)
		Phase.PHASE_2_TRANSITION:
			is_invulnerable = true
			_set_hurtbox(false)
			# Director controls visuals here (shield shatter)
		Phase.PHASE_3:
			is_invulnerable = false
			_set_hurtbox(true)
			_play_animation(ANIM_PHASE3_IDLE)
			# Reset HP to config value at phase start
			if config != null:
				current_hp = config.phase3_start_hp
			else:
				current_hp = 100
			health_changed.emit(current_hp, _get_max_hp())
		Phase.FINAL_PURIFICATION:
			is_invulnerable = true
			_set_hurtbox(false)
			_final_purification_active = true
			_play_animation(ANIM_DYING)
			_start_final_defeat_visuals()
			final_purification_started.emit()
		Phase.DEFEATED:
			is_battle_active = false
			is_invulnerable = true
			_set_hurtbox(false)
			_play_animation(ANIM_PURIFIED)
			boss_defeated.emit(&"crownland_king")
		Phase.RESET:
			reset_battle()


func enter_phase_1_transition() -> void:
	_set_phase(Phase.PHASE_1_TRANSITION)


func enter_phase_2() -> void:
	_set_phase(Phase.PHASE_2)


func enter_phase_2_transition() -> void:
	_set_phase(Phase.PHASE_2_TRANSITION)


func enter_phase_3() -> void:
	_set_phase(Phase.PHASE_3)


func enter_final_purification() -> void:
	if current_phase == Phase.FINAL_PURIFICATION or current_phase == Phase.DEFEATED:
		return
	_set_phase(Phase.FINAL_PURIFICATION)


func enter_defeated() -> void:
	_set_phase(Phase.DEFEATED)


func _update_phase2_float(delta: float) -> void:
	if _visual_root == null:
		return
	if current_phase != Phase.PHASE_2:
		return
	_phase2_float_time += delta * phase2_float_speed
	_visual_root.position = _visual_root_base_position + Vector2(0.0, sin(_phase2_float_time) * phase2_float_amplitude)


func _start_final_defeat_visuals() -> void:
	if _visual_root == null:
		return
	_final_shake_remaining = 1.25
	if _final_white_tween != null and _final_white_tween.is_valid():
		_final_white_tween.kill()
	_final_white_tween = create_tween()
	if _final_white_tween != null:
		_final_white_tween.tween_property(_visual_root, "modulate", Color.WHITE, 1.1)


func _update_final_defeat_shake(delta: float) -> void:
	if _final_shake_remaining <= 0.0 or _visual_root == null:
		return
	_final_shake_remaining = maxf(_final_shake_remaining - delta, 0.0)
	_visual_root.position = _visual_root_base_position + Vector2(
		randf_range(-_final_shake_amplitude, _final_shake_amplitude),
		randf_range(-_final_shake_amplitude * 0.65, _final_shake_amplitude * 0.65)
	)
	if is_zero_approx(_final_shake_remaining):
		_visual_root.position = _visual_root_base_position


# ═══════════════════════════════════════════════════════════════
#  POTION HIT INTERFACE  (called by potion throw system)
# ═══════════════════════════════════════════════════════════════

## Primary entry point — called by the potion throw system on any hit.
func receive_potion_hit(hit: Dictionary) -> void:
	if current_phase == Phase.DEFEATED or current_phase == Phase.RESET:
		return

	var potion_id: String = String(hit.get("potion_id", ""))
	var base_damage: float = float(hit.get("damage", 10))

	# ── Final Purification: only holy water completes the kill ──
	if _final_purification_active:
		if _is_holy_water(potion_id):
			_complete_purification()
		else:
			_show_hint("需要圣水才能彻底终结寄生。")
		return

	# ── Phase 1 & 2: Boss is invulnerable ──
	if current_phase == Phase.PHASE_1 or current_phase == Phase.PHASE_1_TRANSITION or current_phase == Phase.PHASE_2:
		_play_shield_ripple()
		if not _shield_hint_shown:
			_shield_hint_shown = true
			_show_hint("攻击无法穿透王权屏障。")
		shield_hit.emit()
		return

	# ── Phase 3: real damage with color resistance ──
	if current_phase == Phase.PHASE_3:
		var color_key := _get_color_key(potion_id)
		var multiplier := _get_color_multiplier(color_key)
		var final_damage := maxi(1, roundi(base_damage * multiplier))
		_apply_boss_damage(final_damage)
		_update_color_resistance(color_key)
		_play_hit_flash()


func _apply_boss_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
	health_changed.emit(current_hp, _get_max_hp())
	if current_hp <= 0:
		enter_final_purification()


func _get_max_hp() -> int:
	return config.max_hp if config != null else 100


# ─── Holy water check ───
func _is_holy_water(potion_id: String) -> bool:
	if config == null:
		for tag: String in ["holy", "sacred", "圣水"]:
			if tag in potion_id:
				return true
		return false
	for tag: String in config.holy_water_tags:
		if tag in potion_id:
			return true
	return false


# ─── Color resistance ───
func _get_color_key(potion_id: String) -> String:
	# Map potion_id to a color family key
	const COLOR_MAP: Array[Array] = [
		["red", "bomb", "fire", "explo"],
		["blue", "ice", "cyan", "pure", "purif"],
		["green", "poison", "acid"],
		["yellow", "elec", "spark"],
		["purple", "shadow", "dark"],
		["white", "light", "holy", "sacred"],
	]
	for pair: Array in COLOR_MAP:
		var key: String = pair[0]
		for tag in pair:
			if tag in potion_id:
				return key
	return potion_id   # fallback: use full id as key


func _get_color_multiplier(color_key: String) -> float:
	var tiers: Array[float] = [1.0, 0.80, 0.60, 0.40]
	if config != null and not config.resist_tier.is_empty():
		tiers = config.resist_tier
	if color_key != _last_color_key:
		return tiers[0]
	var idx := mini(_color_hit_count.get(color_key, 0), tiers.size() - 1)
	return tiers[idx]


func _update_color_resistance(color_key: String) -> void:
	if color_key != _last_color_key:
		_last_color_key = color_key
		_color_hit_count = {}
	_color_hit_count[color_key] = _color_hit_count.get(color_key, 0) + 1
	_color_timer = 0.0


func _reset_color_resistance() -> void:
	_color_hit_count = {}
	_last_color_key = ""
	_color_timer = 0.0


# ─── Final purification completion ───
func _complete_purification() -> void:
	_final_purification_active = false
	# Brief bullet-time via Engine.time_scale
	var scale := 0.3 if config == null else config.bullet_time_scale
	var duration := 1.5 if config == null else config.bullet_time_duration
	Engine.time_scale = scale
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			await tree.create_timer(duration * scale).timeout  # real-time wait
	Engine.time_scale = 1.0
	enter_defeated()


# ═══════════════════════════════════════════════════════════════
#  VISUAL HELPERS
# ═══════════════════════════════════════════════════════════════

func _set_hurtbox(enabled: bool) -> void:
	if _hurtbox != null:
		# Layer 3 is the shared potion-query layer. Keep the physical shape in
		# the scene so it is visible in-editor; only Phase 3 opens the target.
		_hurtbox.collision_layer = 4
		_hurtbox.collision_mask = 0
		_hurtbox.monitorable = enabled
		_hurtbox.monitoring = enabled


func _play_shield_ripple() -> void:
	if _shield_visual == null:
		return
	if _shield_tween != null and _shield_tween.is_valid():
		_shield_tween.kill()
	_shield_visual.modulate.a = 1.0
	_shield_tween = create_tween()
	if _shield_tween != null:
		_shield_tween.tween_property(_shield_visual, "modulate:a", 0.0,
			config.shield_ripple_duration if config else 0.4)


func _play_hit_flash() -> void:
	if _visual_root == null:
		return
	if _hit_flash_tween != null and _hit_flash_tween.is_valid():
		_hit_flash_tween.kill()
	var dur := config.hit_flash_duration if config else 0.08
	var ret := config.hit_recoil_return_time if config else 0.06
	var recoil_max := config.hit_recoil_max_px if config else 12.0
	var offset := Vector2(randf_range(-recoil_max, recoil_max), randf_range(-recoil_max * 0.5, recoil_max * 0.5))
	_visual_root.modulate = Color(1.5, 1.5, 1.5, 1.0)
	_visual_root.position = offset
	_hit_flash_tween = create_tween()
	if _hit_flash_tween != null:
		_hit_flash_tween.tween_property(_visual_root, "modulate", Color.WHITE, dur)
		_hit_flash_tween.parallel().tween_property(_visual_root, "position", Vector2.ZERO, ret)


func _play_animation(anim_name: StringName) -> void:
	if _sprite != null and _sprite.sprite_frames != null:
		if _sprite.sprite_frames.has_animation(anim_name):
			_sprite.play(anim_name)
			return
	# Fallback: play idle if target animation not yet wired up
	if _sprite != null and _sprite.sprite_frames != null:
		if _sprite.sprite_frames.has_animation(ANIM_IDLE):
			_sprite.play(ANIM_IDLE)


func _show_hint(text: String) -> void:
	# Walk up to find a hint display node (TopHintUI / HintLabel)
	var hint_ui := _find_hint_ui()
	if hint_ui != null:
		if hint_ui.has_method("show_hint"):
			hint_ui.call("show_hint", text)
		elif hint_ui.has_method("show_message"):
			hint_ui.call("show_message", text)
		elif hint_ui is Label:
			(hint_ui as Label).text = text
	# Also signal arena which can relay to HUD
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var arena := tree.get_first_node_in_group("crownland_arena")
			if arena != null and arena.has_method("show_hint"):
				arena.call("show_hint", text)


func _find_hint_ui() -> Node:
	var p: Node = get_parent()
	while p != null:
		var ui := p.get_node_or_null("UI/HintLabel")
		if ui != null:
			return ui
		var top := p.get_node_or_null("GlobalUI/TopHintUI")
		if top != null:
			return top
		p = p.get_parent()
	if is_inside_tree() and get_tree() != null:
		return get_tree().get_first_node_in_group("hint_ui")
	return null


# ─── Public accessors for Director ───
func get_attack_origin() -> Vector2:
	return _attack_origin.global_position if _attack_origin != null else global_position


func get_left_origin() -> Vector2:
	return _left_origin.global_position if _left_origin != null else global_position + Vector2(-200, 0)


func get_right_origin() -> Vector2:
	return _right_origin.global_position if _right_origin != null else global_position + Vector2(200, 0)

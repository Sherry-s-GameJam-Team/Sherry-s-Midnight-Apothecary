class_name AlkeonBoss
extends Node2D

signal health_changed(current_hp: float, max_hp: float)
signal phase_changed(new_phase: int)
signal boss_purified
signal head_bowed(duration: float)
signal head_raised
signal transformation_started(phase_target: int)
signal transformation_finished(phase_target: int)

enum Phase {
	PHASE1_RED_HORN,    # 100% -> 67%
	TRANSITION_1_TO_2,
	PHASE2_WILD_HUNT,   # 67% -> 34%
	TRANSITION_2_TO_3,
	PHASE3_GREAT_HUNT,  # 34% -> 0%
	FINAL_PURIFICATION, # <= 10%
	PURIFIED_RESTORED   # 0%
}

enum HeadState {
	NORMAL,
	BOWED,
	FINAL_EXPOSED
}

@export var max_hp: float = 100.0
@export var current_hp: float = 100.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var restored_sprite: Sprite2D = $RestoredSprite
@onready var leaf_shield: Node2D = $LeafShield
@onready var shield_particles: GPUParticles2D = $LeafShield/ShieldParticles
@onready var disaster_core: Area2D = $DisasterCore
@onready var core_sprite: Sprite2D = $DisasterCore/CoreVisual

var current_phase: Phase = Phase.PHASE1_RED_HORN
var head_state: HeadState = HeadState.NORMAL

var _shield_broken: bool = false
var _wind_barrier_active: bool = false
var _final_step: int = 0 # 0=Need Explosion, 1=Need Wind, 2=Need Purification
var _bowed_timer: float = 0.0
var _base_position: Vector2 = Vector2.ZERO
var _float_time: float = 0.0
var _is_transitioning: bool = false


func _ready() -> void:
	_base_position = position
	current_hp = max_hp
	add_to_group("alkeon_boss")
	add_to_group("potion_target")

	if disaster_core != null:
		disaster_core.collision_layer = 1 | 2
		disaster_core.collision_mask = 3

	_update_visual_for_phase()
	_reset_shield()


func _process(delta: float) -> void:
	# Gentle majestic breathing/floating
	_float_time += delta * 1.6
	if not _is_transitioning and head_state != HeadState.BOWED:
		position.y = _base_position.y + sin(_float_time) * 10.0

	if head_state == HeadState.BOWED or head_state == HeadState.FINAL_EXPOSED:
		_bowed_timer -= delta
		if _bowed_timer <= 0.0:
			raise_head()


func enter_bowed_state(duration: float = 3.5) -> void:
	if _is_transitioning or current_phase == Phase.PURIFIED_RESTORED:
		return

	head_state = HeadState.BOWED
	_bowed_timer = duration
	_shield_broken = false
	_wind_barrier_active = false
	_final_step = 0

	# Bow down visually
	var tw := create_tween()
	tw.tween_property(self, "position:y", _base_position.y + 55.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	head_bowed.emit(duration)


func enter_final_purification_window() -> void:
	if current_phase == Phase.PURIFIED_RESTORED:
		return
	head_state = HeadState.FINAL_EXPOSED
	_bowed_timer = 12.0
	_shield_broken = false
	_wind_barrier_active = false
	_final_step = 0

	var tw := create_tween()
	tw.tween_property(self, "position:y", _base_position.y + 40.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if disaster_core != null:
		disaster_core.visible = true
	head_bowed.emit(12.0)


func raise_head() -> void:
	if current_phase == Phase.PURIFIED_RESTORED:
		return

	head_state = HeadState.NORMAL
	_reset_shield()

	var tw := create_tween()
	tw.tween_property(self, "position:y", _base_position.y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	head_raised.emit()


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: StringName = hit.get("potion_id", &"")
	var pid_str := String(potion_id).to_lower()

	if head_state == HeadState.NORMAL:
		# Shield reflects or absorbs
		_flash_shield()
		return

	if head_state == HeadState.BOWED:
		# Phase 1 & 2 vulnerability
		if not _shield_broken:
			if pid_str.contains("explosion") or pid_str.contains("burst") or pid_str.contains("bomb"):
				_break_shield()
			else:
				_flash_shield()
		else:
			if pid_str.contains("purification") or pid_str.contains("pure") or pid_str.contains("cure"):
				_apply_core_damage(12.0)
				raise_head()

	elif head_state == HeadState.FINAL_EXPOSED:
		# Phase 3 Three-Step Purification Puzzle
		match _final_step:
			0:
				if pid_str.contains("explosion") or pid_str.contains("bomb"):
					_final_step = 1
					_break_shield()
				else:
					_flash_shield()
			1:
				if pid_str.contains("wind") or pid_str.contains("gust"):
					_final_step = 2
					_activate_wind_lock()
				else:
					_flash_shield()
			2:
				if pid_str.contains("purification") or pid_str.contains("pure"):
					_trigger_purified_victory()
				else:
					_flash_shield()


func apply_potion_effect(effect_id: StringName, _context: Dictionary = {}) -> void:
	var eid_str := String(effect_id).to_lower()
	if head_state == HeadState.BOWED:
		if not _shield_broken and (eid_str.contains("explosion") or eid_str.contains("burst")):
			_break_shield()
	elif head_state == HeadState.FINAL_EXPOSED:
		if _final_step == 1 and (eid_str.contains("wind") or eid_str.contains("gust")):
			_final_step = 2
			_activate_wind_lock()


func _apply_core_damage(amount: float) -> void:
	current_hp = maxf(0.0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)

	# Check Phase transition thresholds
	if current_phase == Phase.PHASE1_RED_HORN and current_hp <= 67.0:
		_start_phase_transition(Phase.PHASE2_WILD_HUNT)
	elif current_phase == Phase.PHASE2_WILD_HUNT and current_hp <= 34.0:
		_start_phase_transition(Phase.PHASE3_GREAT_HUNT)


func _start_phase_transition(target_phase: Phase) -> void:
	_is_transitioning = true
	head_state = HeadState.NORMAL
	var trans_phase := Phase.TRANSITION_1_TO_2 if target_phase == Phase.PHASE2_WILD_HUNT else Phase.TRANSITION_2_TO_3
	current_phase = trans_phase
	phase_changed.emit(int(current_phase))
	transformation_started.emit(int(target_phase))

	# Play 4-second transformation sequence
	if animated_sprite != null:
		var start_frame := 0 if target_phase == Phase.PHASE2_WILD_HUNT else 8
		var end_frame := 8 if target_phase == Phase.PHASE2_WILD_HUNT else 16
		var tw := create_tween()
		tw.tween_method(func(val: float) -> void:
			animated_sprite.frame = clampi(int(val), 0, 23)
		, float(start_frame), float(end_frame), 3.8)
		tw.tween_callback(func() -> void:
			current_phase = target_phase
			_is_transitioning = false
			_update_visual_for_phase()
			phase_changed.emit(int(current_phase))
			transformation_finished.emit(int(target_phase))
		)


func _trigger_purified_victory() -> void:
	current_hp = 0.0
	current_phase = Phase.PURIFIED_RESTORED
	health_changed.emit(0.0, max_hp)
	head_state = HeadState.NORMAL

	if leaf_shield != null:
		leaf_shield.visible = false
	if disaster_core != null:
		disaster_core.visible = false

	# Play restoration morph to Sacred Deer Spirit
	if animated_sprite != null:
		animated_sprite.visible = false
	if restored_sprite != null:
		restored_sprite.visible = true
		restored_sprite.modulate = Color(1.5, 1.5, 1.5, 0.0)
		var tw := create_tween()
		tw.tween_property(restored_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.5)
		tw.tween_property(self, "position:y", _base_position.y + 20.0, 1.2).set_trans(Tween.TRANS_SINE)

	boss_purified.emit()


func _break_shield() -> void:
	_shield_broken = true
	if leaf_shield != null:
		var tw := create_tween()
		tw.tween_property(leaf_shield, "scale", Vector2(1.3, 1.3), 0.1)
		tw.tween_property(leaf_shield, "modulate:a", 0.0, 0.2)
	if disaster_core != null:
		disaster_core.visible = true
		disaster_core.modulate = Color(1.5, 1.5, 1.5, 1.0)


func _activate_wind_lock() -> void:
	_wind_barrier_active = true
	if disaster_core != null:
		disaster_core.modulate = Color(0.4, 1.4, 1.2, 1.0)


func _flash_shield() -> void:
	if leaf_shield != null:
		var tw := create_tween()
		tw.tween_property(leaf_shield, "modulate", Color(2.0, 0.6, 0.6, 1.0), 0.08)
		tw.tween_property(leaf_shield, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15)


func _reset_shield() -> void:
	_shield_broken = false
	_wind_barrier_active = false
	_final_step = 0
	if leaf_shield != null:
		leaf_shield.visible = (current_phase != Phase.PURIFIED_RESTORED)
		leaf_shield.scale = Vector2.ONE
		leaf_shield.modulate = Color(1.0, 1.0, 1.0, 1.0)
	if disaster_core != null:
		disaster_core.visible = false


func _update_visual_for_phase() -> void:
	if animated_sprite == null:
		return

	match current_phase:
		Phase.PHASE1_RED_HORN:
			animated_sprite.frame = 0
			animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		Phase.PHASE2_WILD_HUNT:
			animated_sprite.frame = 8
			animated_sprite.modulate = Color(1.1, 0.85, 0.85, 1.0)
		Phase.PHASE3_GREAT_HUNT, Phase.FINAL_PURIFICATION:
			animated_sprite.frame = 16
			animated_sprite.modulate = Color(1.2, 0.6, 0.6, 1.0)
		Phase.PURIFIED_RESTORED:
			animated_sprite.visible = false
			if restored_sprite != null:
				restored_sprite.visible = true

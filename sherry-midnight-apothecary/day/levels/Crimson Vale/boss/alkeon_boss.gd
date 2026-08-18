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
@onready var weakpoint_indicator: AlkeonWeakpointIndicator = get_node_or_null("DisasterCore/WeakpointIndicator")

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
	if not _is_transitioning and head_state != HeadState.BOWED and head_state != HeadState.FINAL_EXPOSED:
		position.y = _base_position.y + sin(_float_time) * 10.0

	# Only standard vulnerability has a timeout. FINAL_EXPOSED remains active for climax execution.
	if head_state == HeadState.BOWED:
		_bowed_timer -= delta
		if _bowed_timer <= 0.0:
			raise_head()


func enter_bowed_state(duration: float = 3.5) -> void:
	if _is_transitioning or current_phase == Phase.PURIFIED_RESTORED:
		return

	head_state = HeadState.BOWED
	_bowed_timer = duration
	_shield_broken = (current_phase == Phase.PHASE3_GREAT_HUNT)
	_wind_barrier_active = false
	_final_step = 0

	if disaster_core != null:
		disaster_core.visible = true
	if weakpoint_indicator != null:
		if current_phase == Phase.PHASE3_GREAT_HUNT:
			weakpoint_indicator.activate("core_exposed")
		else:
			weakpoint_indicator.activate("shield")

	# Bow down visually
	var tw := create_tween()
	tw.tween_property(self, "position:y", _base_position.y + 55.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	head_bowed.emit(duration)


func enter_final_purification_window() -> void:
	if current_phase == Phase.PURIFIED_RESTORED:
		return
	current_phase = Phase.FINAL_PURIFICATION
	head_state = HeadState.FINAL_EXPOSED
	_shield_broken = true
	_wind_barrier_active = false
	_final_step = 0

	if disaster_core != null:
		disaster_core.visible = true
	if weakpoint_indicator != null:
		weakpoint_indicator.activate("final_execute")

	var tw := create_tween()
	tw.tween_property(self, "position:y", _base_position.y + 40.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	head_bowed.emit(999.0)


func raise_head() -> void:
	if current_phase == Phase.PURIFIED_RESTORED or current_phase == Phase.FINAL_PURIFICATION:
		return

	head_state = HeadState.NORMAL
	if weakpoint_indicator != null:
		weakpoint_indicator.deactivate()
	_reset_shield()

	var tw := create_tween()
	tw.tween_property(self, "position:y", _base_position.y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	head_raised.emit()


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: StringName = hit.get("potion_id", &"")
	var pid_str := String(potion_id).to_lower()
	var is_pure := pid_str.contains("purification") or pid_str.contains("pure") or pid_str.contains("cure")
	var is_dmg := pid_str.contains("explosion") or pid_str.contains("burst") or pid_str.contains("bomb") or pid_str.contains("attack") or pid_str.contains("red") or is_pure
	var is_wind := pid_str.contains("wind") or pid_str.contains("cyan") or pid_str.contains("gust") or is_pure

	if head_state == HeadState.FINAL_EXPOSED or current_phase == Phase.FINAL_PURIFICATION:
		# Final Execution: ANY potion executes the boss!
		_trigger_purified_victory()
		return

	if head_state == HeadState.NORMAL:
		# Shield reflects or absorbs during bullet barrage
		_flash_shield()
		return

	if head_state == HeadState.BOWED:
		if current_phase == Phase.PHASE3_GREAT_HUNT:
			# Phase 3: Potion hits open weakpoint after dodging barrage
			_apply_core_damage(20.0)
			if weakpoint_indicator != null:
				weakpoint_indicator.play_hit_pulse()
			if current_hp <= 0.0:
				enter_final_purification_window()
			else:
				raise_head()
			return

		# Phase 1 & 2 vulnerability
		if not _shield_broken:
			if is_dmg:
				_break_shield()
				if is_pure:
					_apply_core_damage(12.0)
					raise_head()
			else:
				_flash_shield()
		else:
			if is_pure or is_dmg:
				_apply_core_damage(12.0)
				raise_head()


func apply_potion_effect(effect_id: StringName, _context: Dictionary = {}) -> void:
	var eid_str := String(effect_id).to_lower()
	var is_pure := eid_str.contains("purification") or eid_str.contains("pure") or eid_str.contains("cure")
	var is_dmg := eid_str.contains("explosion") or eid_str.contains("burst") or eid_str.contains("attack") or is_pure
	var is_wind := eid_str.contains("wind") or eid_str.contains("cyan") or eid_str.contains("gust") or is_pure

	if head_state == HeadState.FINAL_EXPOSED or current_phase == Phase.FINAL_PURIFICATION:
		_trigger_purified_victory()
		return

	if head_state == HeadState.NORMAL:
		_flash_shield()
		return

	if head_state == HeadState.BOWED:
		if current_phase == Phase.PHASE3_GREAT_HUNT:
			_apply_core_damage(20.0)
			if weakpoint_indicator != null:
				weakpoint_indicator.play_hit_pulse()
			if current_hp <= 0.0:
				enter_final_purification_window()
			else:
				raise_head()
			return

		if not _shield_broken and is_dmg:
			_break_shield()
			if is_pure:
				_apply_core_damage(12.0)
				raise_head()
		elif _shield_broken and (is_pure or is_dmg):
			_apply_core_damage(12.0)
			raise_head()


func _apply_core_damage(amount: float) -> void:
	current_hp = maxf(0.0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)

	# Check Phase transition thresholds
	if current_phase == Phase.PHASE1_RED_HORN and current_hp <= 67.0:
		_start_phase_transition(Phase.PHASE2_WILD_HUNT)
	elif current_phase == Phase.PHASE2_WILD_HUNT and current_hp <= 34.0:
		_start_phase_transition(Phase.PHASE3_GREAT_HUNT)
	elif current_phase == Phase.PHASE3_GREAT_HUNT and current_hp <= 0.0:
		enter_final_purification_window()


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
			if current_phase == Phase.PHASE3_GREAT_HUNT:
				if disaster_core != null:
					disaster_core.visible = true
				if weakpoint_indicator != null:
					weakpoint_indicator.activate("core_exposed")
			phase_changed.emit(int(current_phase))
			transformation_finished.emit(int(target_phase))
		)


func _trigger_purified_victory() -> void:
	current_hp = 0.0
	current_phase = Phase.PURIFIED_RESTORED
	health_changed.emit(0.0, max_hp)
	head_state = HeadState.NORMAL

	if weakpoint_indicator != null:
		weakpoint_indicator.deactivate()
	if leaf_shield != null:
		leaf_shield.visible = false
	if disaster_core != null:
		disaster_core.visible = false

	# Play convergence & burst execution effect
	var effect_scene: PackedScene = load("res://day/levels/Crimson Vale/boss/alkeon_execution_effect.tscn")
	if effect_scene != null and is_inside_tree():
		var effect: Node2D = effect_scene.instantiate() as Node2D
		get_parent().add_child(effect)
		if effect.has_method("play_execution"):
			effect.call(
				"play_execution",
				global_position + Vector2(0, -50),
				func() -> void:
					# Boss vanishes upon explosion
					visible = false
					if animated_sprite != null: animated_sprite.visible = false
					if restored_sprite != null: restored_sprite.visible = false
					boss_purified.emit()
			)
		else:
			visible = false
			boss_purified.emit()
	else:
		visible = false
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
	if weakpoint_indicator != null:
		if head_state == HeadState.FINAL_EXPOSED:
			weakpoint_indicator.set_mode("final_1")
		else:
			weakpoint_indicator.set_mode("core_exposed")


func _activate_wind_lock() -> void:
	_wind_barrier_active = true
	if disaster_core != null:
		disaster_core.modulate = Color(0.4, 1.4, 1.2, 1.0)
	if weakpoint_indicator != null:
		weakpoint_indicator.set_mode("final_2")


func _flash_shield() -> void:
	if weakpoint_indicator != null and weakpoint_indicator.visible:
		weakpoint_indicator.play_hit_pulse()
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

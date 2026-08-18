class_name BloodLeafSwarm
extends Node2D

signal telegraph_started
signal attack_started
signal dispersed(duration: float)
signal wind_blown(direction: Vector2, strength: float)
signal damaged(remaining_hp: float)
signal purified
signal finished

enum State {
	IDLE,
	TELEGRAPH,
	TRACKING,
	DISPERSED,
	COOLDOWN,
	PURIFIED,
	FINISHED
}

@export_group("Targeting & Timing")
@export var target: Node2D
@export var auto_target_player: bool = true
@export var auto_start: bool = true
@export var proximity_trigger: bool = true
@export_range(50.0, 2000.0, 20.0) var detection_radius: float = 750.0
@export_range(100.0, 3000.0, 50.0) var leashing_radius: float = 1600.0
@export_range(0.1, 5.0, 0.05) var telegraph_time: float = 0.7
@export_range(0.5, 30.0, 0.1) var attack_duration: float = 4.0
@export_range(0.05, 2.0, 0.05) var tracking_delay: float = 0.55
@export_range(20.0, 1000.0, 10.0) var anchor_speed: float = 280.0
@export var loop_attacks: bool = true
@export_range(0.5, 10.0, 0.1) var loop_interval: float = 1.6

@export_group("Combat & Stats")
@export_range(0.0, 100.0, 1.0) var damage: float = 1.0
@export_range(0.0, 1000.0, 10.0) var knockback_force: float = 180.0
@export_range(1.0, 20.0, 1.0) var corruption_hp: float = 3.0
@export_range(10.0, 300.0, 5.0) var core_radius: float = 60.0:
	set(value):
		core_radius = value
		_update_collision_shape()

@export_group("Visual Tuning")
@export_range(0.2, 3.0, 0.1) var scale_multiplier: float = 1.0
@export var telegraph_circle_color: Color = Color(0.88, 0.2, 0.2, 0.45)

@onready var leaf_particles_a: GPUParticles2D = get_node_or_null("LeafParticlesA")
@onready var leaf_particles_b: GPUParticles2D = get_node_or_null("LeafParticlesB")
@onready var damage_area: Area2D = get_node_or_null("DamageArea")
@onready var collision_shape: CollisionShape2D = get_node_or_null("DamageArea/CollisionShape2D")
@onready var damage_tick: Timer = get_node_or_null("DamageTick")
@onready var telegraph_node: Node2D = get_node_or_null("Telegraph")
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

var _particle_emitters: Array[GPUParticles2D] = []
var _current_state: State = State.IDLE
var _spawn_origin: Vector2 = Vector2.ZERO
var _state_timer: float = 0.0
var _attack_elapsed: float = 0.0
var _disperse_remaining: float = 0.0
var _current_hp: float = 3.0
var _current_anchor_pos: Vector2 = Vector2.ZERO
var _wind_velocity: Vector2 = Vector2.ZERO
var _disperse_factor: float = 0.0
var _chase_intensity: float = 0.0
var _history: Array[Dictionary] = [] # Elements: { "time": float, "pos": Vector2 }
var _is_purified: bool = false
var _wind_tween: Tween
var _disperse_tween: Tween
var _fade_tween: Tween
var _intensity_tween: Tween


const MAX_CONCURRENT_SWARMS: int = 4


func _ready() -> void:
	add_to_group("blood_leaf_swarm")
	add_to_group("hazard")
	add_to_group("corrupted")
	add_to_group("potion_target")
	add_to_group("potion_interactive")

	if is_inside_tree():
		var swarms := get_tree().get_nodes_in_group("blood_leaf_swarm").filter(func(n: Node) -> bool: return n is BloodLeafSwarm and n != self and not bool(n.get("_is_purified")))
		if swarms.size() >= MAX_CONCURRENT_SWARMS:
			queue_free()
			return

	_current_hp = corruption_hp
	_spawn_origin = global_position
	_current_anchor_pos = global_position
	_update_collision_shape()

	_find_all_particle_emitters()

	if damage_area != null:
		damage_area.add_to_group("blood_leaf_swarm")
		damage_area.position = Vector2.ZERO
		damage_area.monitoring = false
		damage_area.monitorable = true

	if damage_tick != null and not damage_tick.timeout.is_connected(_on_damage_tick):
		damage_tick.timeout.connect(_on_damage_tick)

	_setup_materials()
	_set_particles_emitting(true)
	_set_particles_alpha(0.85)

	_update_target_reference()

	if auto_start:
		if proximity_trigger and target != null:
			var dist := _current_anchor_pos.distance_to(target.global_position)
			if dist <= detection_radius and not is_target_sheltered():
				start_attack(target)
			else:
				_enter_idle_state()
		elif proximity_trigger:
			_enter_idle_state()
		else:
			start_attack(target)


func _physics_process(delta: float) -> void:
	_update_target_reference()
	_record_target_history()

	match _current_state:
		State.IDLE:
			_process_idle(delta)
		State.TELEGRAPH:
			_process_telegraph(delta)
		State.TRACKING:
			_process_tracking(delta)
		State.DISPERSED:
			_process_dispersed(delta)
		State.COOLDOWN:
			_process_cooldown(delta)
		State.PURIFIED, State.FINISHED:
			pass

	# Anchor position drives global position of the node
	global_position = _current_anchor_pos
	_sync_shader_uniforms()


func is_target_sheltered() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.get_meta("sheltered", false):
		return true
	if target.is_in_group("sheltered"):
		return true
	if Time.get_ticks_msec() <= int(target.get_meta("potion_concealed_until_ms", 0)):
		return true
	return false


func start_attack(new_target: Node2D = null) -> void:
	if _is_purified:
		return
	if new_target != null:
		target = new_target
	_update_target_reference()

	if is_target_sheltered():
		_enter_idle_state()
		return

	_current_state = State.TELEGRAPH
	_state_timer = 0.0
	_attack_elapsed = 0.0

	_history.clear()
	if target != null and is_instance_valid(target):
		_history.append({"time": _get_time_sec(), "pos": target.global_position})

	if damage_area != null:
		damage_area.monitoring = false

	_set_particles_emitting(true)
	_set_particles_alpha(0.9)
	_animate_chase_intensity(0.35, 0.4)
	_set_telegraph_visible(true)

	if damage_tick != null and damage_tick.is_stopped():
		damage_tick.start()

	telegraph_started.emit()


func stop_attack() -> void:
	_current_state = State.IDLE
	if damage_area != null:
		damage_area.monitoring = false
	if damage_tick != null:
		damage_tick.stop()
	_set_telegraph_visible(false)
	_animate_chase_intensity(0.0, 0.5)


func hit_by_wind(direction: Vector2, strength: float = 420.0, duration: float = 0.8) -> void:
	if _is_purified:
		return
	var dir := direction.normalized()
	if dir.is_zero_approx():
		dir = Vector2.UP

	# Displace anchor and impart directional shader wind
	_current_anchor_pos += dir * (strength * 0.35)
	global_position = _current_anchor_pos

	_wind_velocity = dir * strength
	if _wind_tween != null and _wind_tween.is_valid():
		_wind_tween.kill()
	var tw := _safe_create_tween()
	if tw != null:
		_wind_tween = tw
		_wind_tween.tween_method(_set_wind_velocity_value, _wind_velocity, Vector2.ZERO, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	wind_blown.emit(direction, strength)


func take_damage(amount: float) -> void:
	if _is_purified:
		return
	_current_hp -= amount
	damaged.emit(_current_hp)

	# Visual flash / momentary scattering response
	var hit_tween := _safe_create_tween()
	if hit_tween != null:
		hit_tween.tween_method(_set_disperse_factor_value, 0.9, 0.0, 0.3)

	if _current_hp <= 0.0:
		_purify_and_dismiss()


func receive_hit(damage_amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	take_damage(damage_amount)
	if not _is_purified and not knockback.is_zero_approx():
		hit_by_wind(knockback.normalized(), knockback.length(), 0.5)


func receive_damage(amount: float) -> void:
	take_damage(amount)


func hit_by_explosion(explosion_position: Vector2, strength: float = 1.0) -> void:
	if _is_purified:
		return
	# Deal normal/explosion damage to eliminate swarm
	_current_hp -= strength * 1.5
	damaged.emit(_current_hp)

	if _current_hp <= 0.0:
		_purify_and_dismiss()
		return

	var disperse_duration := randf_range(0.45, 0.7)
	var away := (_current_anchor_pos - explosion_position).normalized()
	if away.is_zero_approx():
		away = Vector2.UP

	_current_anchor_pos += away * (100.0 * strength)
	global_position = _current_anchor_pos
	if damage_area != null:
		damage_area.monitoring = false

	_disperse_factor = clampf(strength * 1.5, 0.8, 2.5)
	_disperse_remaining = disperse_duration
	_current_state = State.DISPERSED

	if _disperse_tween != null and _disperse_tween.is_valid():
		_disperse_tween.kill()
	var tw := _safe_create_tween()
	if tw != null:
		_disperse_tween = tw
		_disperse_tween.tween_method(_set_disperse_factor_value, _disperse_factor, 0.0, disperse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	dispersed.emit(disperse_duration)


func hit_by_purification(power: float = 1.0) -> void:
	if _is_purified:
		return
	_current_hp -= power
	damaged.emit(_current_hp)

	# Visual flash / momentary scattering response
	var hit_tween := _safe_create_tween()
	if hit_tween != null:
		hit_tween.tween_method(_set_disperse_factor_value, 0.8, 0.0, 0.35)

	if _current_hp <= 0.0:
		_purify_and_dismiss()


func apply_potion_effect(effect_id: StringName, context: Dictionary = {}) -> void:
	if _is_purified:
		return
	var impact_pt: Vector2 = context.get("impact_point", global_position)
	var multiplier: float = float(context.get("multiplier", 1.0))
	var potency: float = float(context.get("potency", 1.0))
	var combined_power: float = multiplier * potency
	var eid_str := String(effect_id).to_lower()

	if eid_str.contains("attack") or eid_str.contains("lightning") or eid_str.contains("explosion"):
		hit_by_explosion(impact_pt, combined_power)
	elif eid_str.contains("purif") or eid_str.contains("cure"):
		hit_by_purification(combined_power * 3.0)
	elif eid_str.contains("speed") or eid_str.contains("wind") or eid_str.contains("cyan"):
		var dir := (global_position - impact_pt).normalized()
		if dir.is_zero_approx():
			var normal: Vector2 = context.get("impact_normal", Vector2.UP)
			dir = -normal if not normal.is_zero_approx() else Vector2.UP
		hit_by_wind(dir, 450.0 * combined_power, 0.8)
	else:
		take_damage(combined_power * 1.5)


func receive_potion_hit(hit: Dictionary) -> void:
	if _is_purified:
		return
	var potion: PotionData = hit.get("potion")
	var potion_id: StringName = hit.get("potion_id", &"")
	var effect_id: StringName = hit.get("main_effect_id", &"")
	var pt: Vector2 = hit.get("impact_point", global_position)
	var pid_str := String(potion_id).to_lower()

	if potion != null and potion.main_effect_id != &"":
		apply_potion_effect(potion.main_effect_id, {
			"impact_point": pt,
			"multiplier": 1.0,
			"potency": 1.0
		})
	elif effect_id != &"":
		apply_potion_effect(effect_id, { "impact_point": pt })
	elif pid_str.contains("red") or pid_str.contains("attack") or pid_str.contains("explosion"):
		hit_by_explosion(pt, 1.5)
	elif pid_str.contains("purif") or pid_str.contains("pure"):
		hit_by_purification(3.0)
	elif pid_str.contains("orange") or pid_str.contains("cyan") or pid_str.contains("wind"):
		var dir := (global_position - pt).normalized()
		hit_by_wind(dir if not dir.is_zero_approx() else Vector2.UP, 450.0, 0.8)
	else:
		take_damage(1.5)


func _enter_idle_state() -> void:
	_current_state = State.IDLE
	if damage_area != null:
		damage_area.monitoring = false
	_set_telegraph_visible(false)
	_set_particles_emitting(true)
	_set_particles_alpha(0.85)
	_animate_chase_intensity(0.0, 0.6)


func _process_idle(delta: float) -> void:
	# Gently float near spawn origin
	_current_anchor_pos = _current_anchor_pos.move_toward(_spawn_origin, 70.0 * delta)

	if target != null and is_instance_valid(target):
		if is_target_sheltered():
			return
		var dist := _current_anchor_pos.distance_to(target.global_position)
		if dist <= detection_radius:
			start_attack(target)


func _process_telegraph(delta: float) -> void:
	if is_target_sheltered():
		_finish_attack()
		return

	_state_timer += delta
	if telegraph_node != null and telegraph_node.has_method("set_progress"):
		telegraph_node.call("set_progress", clampf(_state_timer / maxf(telegraph_time, 0.01), 0.0, 1.0))

	if _state_timer >= telegraph_time:
		_enter_tracking_state()


func _enter_tracking_state() -> void:
	_current_state = State.TRACKING
	_set_telegraph_visible(false)
	_set_particles_alpha(1.0)
	_animate_chase_intensity(1.0, 0.3)
	if damage_area != null:
		damage_area.monitoring = true
	attack_started.emit()


func _process_tracking(delta: float) -> void:
	if is_target_sheltered():
		_finish_attack()
		return

	_attack_elapsed += delta

	var delayed_target_pos := _get_delayed_target_position()
	_current_anchor_pos = _current_anchor_pos.move_toward(delayed_target_pos, anchor_speed * delta)

	# Check leashing
	if target != null and is_instance_valid(target):
		var dist_to_origin := _current_anchor_pos.distance_to(_spawn_origin)
		if dist_to_origin > leashing_radius:
			_finish_attack()
			return

	if _attack_elapsed >= attack_duration:
		_finish_attack()


func _process_cooldown(delta: float) -> void:
	_state_timer += delta
	# Hover or gently circle in place during cooldown
	if _state_timer >= loop_interval:
		if target != null and is_instance_valid(target) and not is_target_sheltered():
			var dist := _current_anchor_pos.distance_to(target.global_position)
			if dist <= leashing_radius:
				start_attack(target)
				return
		_enter_idle_state()


func _process_dispersed(delta: float) -> void:
	_disperse_remaining -= delta
	if _disperse_remaining <= 0.0:
		if _attack_elapsed < attack_duration and not is_target_sheltered():
			_current_state = State.TRACKING
			if damage_area != null:
				damage_area.monitoring = true
		else:
			_finish_attack()


func _finish_attack() -> void:
	if damage_area != null:
		damage_area.monitoring = false
	_set_telegraph_visible(false)
	finished.emit()

	if loop_attacks and not _is_purified:
		_current_state = State.COOLDOWN
		_state_timer = 0.0
		_set_particles_alpha(0.8)
		_animate_chase_intensity(0.0, 0.6)
	else:
		_current_state = State.FINISHED
		if _fade_tween != null and _fade_tween.is_valid():
			_fade_tween.kill()
		var tw := _safe_create_tween()
		if tw != null:
			_fade_tween = tw
			_fade_tween.tween_method(_set_particles_alpha, 1.0, 0.0, 0.6)


func _purify_and_dismiss() -> void:
	_is_purified = true
	_current_state = State.PURIFIED
	purified.emit()

	if damage_area != null:
		damage_area.monitoring = false
	if damage_tick != null:
		damage_tick.stop()
	_set_telegraph_visible(false)

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var tw := _safe_create_tween()
	if tw != null:
		_fade_tween = tw.set_parallel(true)
		_fade_tween.tween_method(_set_disperse_factor_value, 0.0, 2.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_fade_tween.tween_method(_set_particles_alpha, 1.0, 0.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_fade_tween.chain().tween_callback(queue_free)
	else:
		queue_free()


func _record_target_history() -> void:
	var current_t := _get_time_sec()
	if target != null and is_instance_valid(target):
		_history.append({"time": current_t, "pos": target.global_position})

	# Purge old records older than tracking_delay + 1.5s
	var cutoff := current_t - (tracking_delay + 1.5)
	while _history.size() > 2 and _history[0]["time"] < cutoff:
		_history.remove_at(0)


func _get_delayed_target_position() -> Vector2:
	if target == null or not is_instance_valid(target):
		return _current_anchor_pos

	if _history.is_empty():
		return target.global_position

	var current_t := _get_time_sec()
	var query_t := current_t - tracking_delay

	if query_t <= _history[0]["time"]:
		return _history[0]["pos"]
	if query_t >= _history[-1]["time"]:
		return _history[-1]["pos"]

	# Search for adjacent time bracket
	for i in range(_history.size() - 1):
		var p0: Dictionary = _history[i]
		var p1: Dictionary = _history[i + 1]
		var t0: float = p0["time"]
		var t1: float = p1["time"]
		if query_t >= t0 and query_t <= t1:
			var ratio := (query_t - t0) / maxf(t1 - t0, 0.0001)
			return (p0["pos"] as Vector2).lerp(p1["pos"] as Vector2, ratio)

	return _history[-1]["pos"]


func _on_damage_tick() -> void:
	if _current_state != State.TRACKING or damage_area == null or not damage_area.monitoring:
		return

	var colliders := damage_area.get_overlapping_bodies()
	var overlapping_areas := damage_area.get_overlapping_areas()
	var checked_nodes: Dictionary = {}

	for body: Node in colliders:
		_check_and_damage_player(body, checked_nodes)
	for area: Node in overlapping_areas:
		_check_and_damage_player(area, checked_nodes)


func _check_and_damage_player(node: Node, checked: Dictionary) -> void:
	if node == null:
		return
	var player_node := _find_player_root(node)
	if player_node == null or checked.has(player_node.get_instance_id()):
		return
	checked[player_node.get_instance_id()] = true

	# Don't damage if player is sheltered
	if is_target_sheltered():
		return

	var knockback_dir := (player_node.global_position - _current_anchor_pos).normalized()
	if knockback_dir.is_zero_approx():
		knockback_dir = Vector2.UP
	var knockback_vector := knockback_dir * knockback_force

	if player_node.has_method("receive_hit"):
		player_node.call("receive_hit", damage, knockback_vector)
	elif player_node.has_method("play_hazard_hit"):
		player_node.call("play_hazard_hit", knockback_vector)

	var day_runtime := _find_day_runtime()
	if day_runtime != null and day_runtime.has_method("apply_player_damage"):
		day_runtime.call("apply_player_damage", damage, &"blood_leaf_swarm")
	elif player_node.has_method("get_player_data"):
		var player_data: Object = player_node.call("get_player_data")
		if player_data != null and player_data.has_method("apply_damage"):
			player_data.call("apply_damage", roundi(damage))


func _find_player_root(node: Node) -> Node2D:
	var curr: Node = node
	while curr != null:
		if curr.is_in_group("player") or curr.name == "Player" or curr is CharacterBody2D:
			return curr as Node2D
		curr = curr.get_parent()
	return null


func _find_day_runtime() -> Node:
	var curr: Node = self
	while curr != null:
		if curr.has_method("apply_player_damage"):
			return curr
		curr = curr.get_parent()
	return null


func _update_target_reference() -> void:
	if target != null and is_instance_valid(target):
		return
	if not auto_target_player or not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return

	# 1. Search group "player"
	var players := tree.get_nodes_in_group("player")
	if not players.is_empty() and is_instance_valid(players[0]):
		target = players[0] as Node2D
		return

	# 2. Search group "potion_friendly" (DayPlayerController joins this in _ready)
	var friendlies := tree.get_nodes_in_group("potion_friendly")
	for node: Node in friendlies:
		if node is CharacterBody2D and is_instance_valid(node):
			target = node as Node2D
			return

	# 3. Search node named "Player" in current level scene
	var scene_root := tree.current_scene if tree.current_scene != null else tree.root
	if scene_root != null:
		var player_node := scene_root.find_child("Player", true, false)
		if player_node is Node2D and is_instance_valid(player_node):
			target = player_node as Node2D
			return


func _update_collision_shape() -> void:
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = core_radius


func _find_all_particle_emitters() -> void:
	_particle_emitters.clear()
	for child: Node in find_children("*", "GPUParticles2D", true, false):
		if child is GPUParticles2D:
			_particle_emitters.append(child as GPUParticles2D)


func _setup_materials() -> void:
	if _particle_emitters.is_empty():
		_find_all_particle_emitters()
	for emitter: GPUParticles2D in _particle_emitters:
		if emitter.process_material is ShaderMaterial:
			emitter.process_material = (emitter.process_material as ShaderMaterial).duplicate()


func _sync_shader_uniforms() -> void:
	_update_material_param("target_position", _current_anchor_pos)
	_update_material_param("wind_velocity", _wind_velocity)
	_update_material_param("disperse", _disperse_factor)
	_update_material_param("chase_intensity", _chase_intensity)


func _update_material_param(param_name: StringName, value: Variant) -> void:
	if _particle_emitters.is_empty():
		_find_all_particle_emitters()
	for emitter: GPUParticles2D in _particle_emitters:
		if emitter.process_material is ShaderMaterial:
			(emitter.process_material as ShaderMaterial).set_shader_parameter(param_name, value)


func _set_particles_emitting(emitting: bool) -> void:
	if _particle_emitters.is_empty():
		_find_all_particle_emitters()
	for emitter: GPUParticles2D in _particle_emitters:
		emitter.emitting = emitting


func _set_particles_alpha(alpha: float) -> void:
	_update_material_param("alpha_mult", alpha)


func _animate_chase_intensity(target_val: float, duration: float) -> void:
	if _intensity_tween != null and _intensity_tween.is_valid():
		_intensity_tween.kill()
	var tw := _safe_create_tween()
	if tw != null:
		_intensity_tween = tw
		_intensity_tween.tween_method(_set_chase_intensity_value, _chase_intensity, target_val, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		_chase_intensity = target_val


func _set_chase_intensity_value(val: float) -> void:
	_chase_intensity = val


func _set_wind_velocity_value(vel: Vector2) -> void:
	_wind_velocity = vel


func _set_disperse_factor_value(val: float) -> void:
	_disperse_factor = val


func _set_telegraph_visible(vis: bool) -> void:
	if telegraph_node != null:
		telegraph_node.visible = vis
		if vis and telegraph_node.has_method("reset"):
			telegraph_node.call("reset")


func _safe_create_tween() -> Tween:
	if is_inside_tree():
		return create_tween()
	return null


func _get_time_sec() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

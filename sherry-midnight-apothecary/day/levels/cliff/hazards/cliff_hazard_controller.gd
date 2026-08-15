class_name CliffHazardController
extends Node

@export var hit_feedback_duration := 0.38
@export var respawn_protection_duration := 1.25
@export var fade_out_duration := 0.22
@export var fade_in_duration := 0.28
@export_range(0, 100, 1) var fall_damage := 15
@export_range(0, 100, 1) var resonance_wave_damage := 12
@export_range(0, 100, 1) var avalanche_damage := 25

@onready var level: CliffResonanceLevel = get_parent().get_parent() as CliffResonanceLevel
@onready var player: CharacterBody2D = level.get_node("Player") as CharacterBody2D
@onready var default_entry: Marker2D = level.get_node("EntryPoints/default") as Marker2D
@onready var fade_rect: ColorRect = level.get_node("UI/FadeRect") as ColorRect
@onready var camera: Camera2D = player.get_node_or_null("Camera2D") as Camera2D

var _handling_hit := false
var _protected_until_ms := 0
var _camera_base_offset := Vector2.ZERO


func _ready() -> void:
	add_to_group("cliff_hazard_controller")
	if camera != null:
		_camera_base_offset = camera.offset


func hit_player(target: Node, hazard_type: StringName, force_direction := Vector2.ZERO, force_magnitude := 0.0) -> void:
	if _handling_hit or not is_instance_valid(target) or target != player or is_hazard_protected():
		return
	if _apply_hazard_damage(hazard_type):
		return
	_handling_hit = true
	_set_control_locked(true)
	var horizontal_force := force_magnitude if force_magnitude > 0.0 else (400.0 if hazard_type == &"avalanche" else 280.0)
	var knockback := Vector2(force_direction.x * horizontal_force, -180.0 if hazard_type == &"avalanche" else -120.0)
	if player.has_method("play_hazard_hit"):
		player.call("play_hazard_hit", knockback)
	else:
		player.velocity = knockback
	shake_camera(9.0 if hazard_type == &"avalanche" else 4.0, 0.45 if hazard_type == &"avalanche" else 0.2)
	await get_tree().create_timer(hit_feedback_duration).timeout
	await _fade_to_default()
	_handling_hit = false


func request_respawn(target: Node, reason: StringName = &"fall", damage: int = -1) -> void:
	if reason == &"fall":
		if _handling_hit or not is_instance_valid(target) or target != player or is_hazard_protected():
			return
		if _apply_hazard_damage(reason, damage):
			return
		_handling_hit = true
		_set_control_locked(true)
		await _fade_to_default()
		_handling_hit = false
		return
	hit_player(target, reason)


func is_hazard_protected() -> bool:
	return Time.get_ticks_msec() < _protected_until_ms


func shake_camera(strength: float, duration: float) -> void:
	if camera == null:
		return
	var tween := create_tween()
	var steps := maxi(2, ceili(duration / 0.045))
	for index in range(steps):
		var falloff := 1.0 - float(index) / float(steps)
		var offset := Vector2(sin(float(index) * 2.4), cos(float(index) * 1.7)) * strength * falloff
		tween.tween_property(camera, "offset", _camera_base_offset + offset, duration / float(steps))
	tween.tween_property(camera, "offset", _camera_base_offset, 0.05)


func trigger_avalanche(zone_name: StringName) -> void:
	for zone: Node in get_tree().get_nodes_in_group("cliff_avalanche_zones"):
		if zone.name == String(zone_name) and zone.has_method("trigger"):
			zone.call("trigger")


func trigger_all_avalanches() -> void:
	for zone: Node in get_tree().get_nodes_in_group("cliff_avalanche_zones"):
		if zone.has_method("trigger"):
			zone.call("trigger")


func trigger_resonance_pillar(pillar_id: StringName) -> void:
	for pillar: Node in get_tree().get_nodes_in_group("cliff_resonance_pillars"):
		if pillar.get("pillar_id") == pillar_id and pillar.has_method("debug_trigger_burst"):
			pillar.call("debug_trigger_burst")


func respawn_player() -> void:
	request_respawn(player, &"fall")


func _apply_hazard_damage(hazard_type: StringName, override_damage: int = -1) -> bool:
	var damage := fall_damage if override_damage < 0 else override_damage
	if hazard_type == &"resonance_wave":
		damage = resonance_wave_damage
	elif hazard_type == &"avalanche":
		damage = avalanche_damage
	var runtime := _find_day_runtime()
	return runtime != null and runtime.apply_player_damage(damage, hazard_type)


func _find_day_runtime() -> DayRuntime:
	var current: Node = self
	while current != null:
		if current is DayRuntime:
			return current as DayRuntime
		current = current.get_parent()
	return null


func _fade_to_default() -> void:
	var fade_out := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_out.tween_property(fade_rect, "modulate:a", 1.0, fade_out_duration)
	await fade_out.finished
	_clear_active_waves()
	player.global_position = default_entry.global_position
	player.velocity = Vector2.ZERO
	if player.has_method("reset_after_hazard"):
		player.call("reset_after_hazard")
	if camera != null:
		camera.offset = _camera_base_offset
	_protected_until_ms = Time.get_ticks_msec() + roundi(respawn_protection_duration * 1000.0)
	var fade_in := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, fade_in_duration)
	await fade_in.finished
	_set_control_locked(false)


func _set_control_locked(locked: bool) -> void:
	if player.has_method("set_dialogue_locked"):
		player.call("set_dialogue_locked", locked)
	if player.has_method("set_potion_action_locked"):
		player.call("set_potion_action_locked", locked)


func _clear_active_waves() -> void:
	for wave: Node in get_tree().get_nodes_in_group("cliff_resonance_wave"):
		if is_instance_valid(wave):
			wave.queue_free()

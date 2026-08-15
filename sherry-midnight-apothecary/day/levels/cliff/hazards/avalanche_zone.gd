class_name CliffAvalancheZone
extends Node2D

enum TriggerMode { AUTO, RESONANCE }

signal avalanche_started(zone_id: StringName)
signal avalanche_finished(zone_id: StringName)

@export_category("Avalanche")
@export var zone_id: StringName = &"avalanche"
@export var zone_size := Vector2(900.0, 650.0)
@export var warning_duration := 2.0
@export var avalanche_duration := 4.0
@export var fade_duration := 0.8
@export var cooldown_duration := 8.0
@export var initial_delay := 4.0
@export var avalanche_direction := Vector2(-0.5, 1.0)
@export var snow_speed := 2.0
@export var snow_density := 1.0
@export var auto_repeat := true
@export var trigger_mode := TriggerMode.AUTO
@export var resonance_source_id: StringName = &""
@export var resonance_trigger_delay := 0.6
@export var debug_draw := false

@onready var warning_visual: ColorRect = $WarningVisual
@onready var snow_visual: ColorRect = $SnowVisual
@onready var front_powder: ColorRect = $FrontPowder
@onready var danger_area: Area2D = $DangerArea
@onready var collision_shape: CollisionShape2D = $DangerArea/CollisionShape2D
@onready var snow_particles: GPUParticles2D = $SnowParticles
@onready var warning_audio: AudioStreamPlayer2D = $AudioAnchor/AvalancheWarning
@onready var rumble_audio: AudioStreamPlayer2D = $AudioAnchor/AvalancheRumble
@onready var impact_audio: AudioStreamPlayer2D = $AudioAnchor/AvalancheImpact

var _active := false
var _cooling_down := false
var _warning_material: ShaderMaterial
var _snow_material: ShaderMaterial
var _front_material: ShaderMaterial


func _ready() -> void:
	add_to_group("cliff_avalanche_zones")
	_apply_zone_size()
	_warning_material = warning_visual.material.duplicate() as ShaderMaterial
	_snow_material = snow_visual.material.duplicate() as ShaderMaterial
	_front_material = front_powder.material.duplicate() as ShaderMaterial
	warning_visual.material = _warning_material
	snow_visual.material = _snow_material
	front_powder.material = _front_material
	_set_strengths(0.0, 0.0, 0.0)
	danger_area.monitoring = false
	snow_particles.emitting = false
	queue_redraw()
	if trigger_mode == TriggerMode.AUTO:
		_run_auto_cycle()


func trigger() -> void:
	if _active or _cooling_down:
		return
	_run_cycle()


func on_resonance_burst(source_id: StringName, _intensity: float) -> void:
	if trigger_mode != TriggerMode.RESONANCE or _active or _cooling_down:
		return
	if not resonance_source_id.is_empty() and resonance_source_id != source_id:
		return
	await get_tree().create_timer(resonance_trigger_delay).timeout
	trigger()


func _run_auto_cycle() -> void:
	await get_tree().create_timer(initial_delay).timeout
	while is_inside_tree():
		await _run_cycle()
		if not auto_repeat:
			return
		await get_tree().create_timer(cooldown_duration).timeout


func _run_cycle() -> void:
	if _active:
		return
	_active = true
	if warning_audio.stream != null:
		warning_audio.play()
	var warning_tween := create_tween()
	warning_tween.tween_method(_set_warning_strength, 0.0, 1.0, warning_duration)
	await warning_tween.finished
	avalanche_started.emit(zone_id)
	var controller := _get_hazard_controller()
	if controller != null:
		controller.shake_camera(8.0, 0.5)
	danger_area.set_deferred("monitoring", true)
	snow_particles.emitting = true
	if rumble_audio.stream != null:
		rumble_audio.play()
	if impact_audio.stream != null:
		impact_audio.play()
	_hit_overlapping_players()
	var burst_tween := create_tween()
	burst_tween.set_parallel(true)
	burst_tween.tween_method(_set_snow_strength, 0.0, 1.0, 0.18)
	burst_tween.tween_method(_set_front_strength, 0.0, 0.58, 0.28)
	await burst_tween.finished
	await get_tree().create_timer(maxf(0.0, avalanche_duration - 0.28)).timeout
	danger_area.set_deferred("monitoring", false)
	snow_particles.emitting = false
	var fade_tween := create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_method(_set_snow_strength, 1.0, 0.0, fade_duration)
	fade_tween.tween_method(_set_front_strength, 0.58, 0.0, fade_duration)
	await fade_tween.finished
	_set_warning_strength(0.0)
	if rumble_audio.playing:
		rumble_audio.stop()
	_active = false
	avalanche_finished.emit(zone_id)
	if trigger_mode == TriggerMode.RESONANCE:
		_cooling_down = true
		await get_tree().create_timer(cooldown_duration).timeout
		_cooling_down = false


func _apply_zone_size() -> void:
	for visual: ColorRect in [warning_visual, snow_visual, front_powder]:
		visual.position = -zone_size * 0.5
		visual.size = zone_size
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = zone_size
	var process_material := snow_particles.process_material as ParticleProcessMaterial
	if process_material != null:
		process_material.emission_box_extents = Vector3(zone_size.x * 0.5, 16.0, 1.0)
		snow_particles.position = Vector2(0.0, -zone_size.y * 0.5)


func _set_strengths(warning: float, snow: float, front: float) -> void:
	_set_warning_strength(warning)
	_set_snow_strength(snow)
	_set_front_strength(front)


func _set_warning_strength(value: float) -> void:
	_warning_material.set_shader_parameter("warning_strength", value)
	warning_visual.visible = value > 0.001
	queue_redraw()


func _set_snow_strength(value: float) -> void:
	_snow_material.set_shader_parameter("snow_strength", value)
	_snow_material.set_shader_parameter("snow_speed", snow_speed)
	_snow_material.set_shader_parameter("snow_density", snow_density)
	_snow_material.set_shader_parameter("flow_direction", avalanche_direction)
	snow_visual.visible = value > 0.001


func _set_front_strength(value: float) -> void:
	_front_material.set_shader_parameter("snow_strength", value)
	_front_material.set_shader_parameter("snow_speed", snow_speed * 1.15)
	_front_material.set_shader_parameter("snow_density", snow_density * 0.8)
	_front_material.set_shader_parameter("flow_direction", avalanche_direction)
	front_powder.visible = value > 0.001


func _on_body_entered(body: Node2D) -> void:
	if not _active or not body.is_in_group("player"):
		return
	var controller := _get_hazard_controller()
	if controller != null:
		controller.hit_player(body, &"avalanche", avalanche_direction.normalized())


func _hit_overlapping_players() -> void:
	await get_tree().physics_frame
	for body: Node2D in danger_area.get_overlapping_bodies():
		_on_body_entered(body)


func _get_hazard_controller() -> CliffHazardController:
	return get_tree().get_first_node_in_group("cliff_hazard_controller") as CliffHazardController


func _draw() -> void:
	if not debug_draw:
		return
	var debug_color := Color(1.0, 0.82, 0.15, 0.18) if not danger_area.monitoring else Color(1.0, 0.12, 0.08, 0.22)
	draw_rect(Rect2(-zone_size * 0.5, zone_size), debug_color, true)

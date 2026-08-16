class_name ForestSprayDevice
extends Node2D

@export var max_pressure := 100.0
@export var drain_rate := 24.0
@export var regen_rate := 20.0
@export var restart_threshold := 30.0
@export var empty_cooldown := 1.0
@export var range := 820.0
@export var min_degrees := -35.0
@export var max_degrees := 35.0
@export var rotate_speed_degrees := 58.0

@onready var interaction_area: Area2D = $InteractionArea
@onready var prompt: Label = $Prompt
@onready var pivot: Node2D = $NozzlePivot
@onready var water_line: Line2D = $NozzlePivot/WaterLine
@onready var nozzle_particles: CPUParticles2D = $NozzlePivot/NozzleParticles
@onready var impact_particles: CPUParticles2D = $NozzlePivot/ImpactParticles

var _luca_inside := false
var _controlling := false
var _pressure := 100.0
var _cooldown_left := 0.0


func _ready() -> void:
	_pressure = max_pressure
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	water_line.visible = false
	nozzle_particles.emitting = false
	impact_particles.emitting = false
	prompt.visible = false


func _exit_tree() -> void:
	if _controlling:
		_end_control()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		if _controlling:
			_end_control()
			get_viewport().set_input_as_handled()
		elif _luca_inside and _is_luca_active():
			_begin_control()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	prompt.visible = _luca_inside and _is_luca_active() and not _controlling
	prompt.text = "[E] 操作水枪"
	if _controlling:
		_update_aim(delta)
		_update_spray(delta)
	else:
		_regenerate_pressure(delta)
	_update_ui()


func _update_aim(delta: float) -> void:
	var input_axis := 0.0
	if Input.is_physical_key_pressed(KEY_W):
		input_axis -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_axis += 1.0
	pivot.rotation_degrees = clampf(
		pivot.rotation_degrees + input_axis * rotate_speed_degrees * delta,
		min_degrees,
		max_degrees
	)


func _update_spray(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
		_regenerate_pressure(delta)
		_set_spray_visual(false)
		return
	if _pressure <= 0.0:
		_cooldown_left = empty_cooldown
		_set_spray_visual(false)
		return
	if _pressure < restart_threshold and not water_line.visible:
		_regenerate_pressure(delta)
		return
	_pressure = maxf(0.0, _pressure - drain_rate * delta)
	_cast_water(delta)


func _regenerate_pressure(delta: float) -> void:
	_pressure = minf(max_pressure, _pressure + regen_rate * delta)


func _cast_water(delta: float) -> void:
	var origin := pivot.global_position
	var direction := Vector2.RIGHT.rotated(pivot.global_rotation)
	var endpoint := origin + direction * range
	var query := PhysicsRayQueryParameters2D.create(origin, endpoint)
	query.collision_mask = 2
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	var local_end := Vector2(range, 0.0)
	var hit_mud := false
	if not hit.is_empty():
		var hit_position: Vector2 = hit["position"]
		local_end = pivot.to_local(hit_position)
		var collider := hit.get("collider") as Object
		if collider != null and collider.has_method("receive_water_jet"):
			collider.call("receive_water_jet", delta)
			hit_mud = true
	water_line.points = PackedVector2Array([Vector2.ZERO, local_end])
	_set_spray_visual(true)
	impact_particles.position = local_end
	impact_particles.emitting = not hit.is_empty()
	if hit_mud:
		impact_particles.amount = 18
	else:
		impact_particles.amount = 8


func _set_spray_visual(enabled: bool) -> void:
	water_line.visible = enabled
	nozzle_particles.emitting = enabled
	if not enabled:
		impact_particles.emitting = false


func _begin_control() -> void:
	if _controlling:
		return
	_controlling = true
	var level := _get_level()
	if level != null:
		level.set_party_switching(false)
	var luca := get_tree().get_first_node_in_group("forest_luca_runtime")
	if luca == null and level != null:
		luca = level.get_node_or_null("Luca")
	if luca != null and luca.has_method("set_control_enabled"):
		luca.call("set_control_enabled", false)


func _end_control() -> void:
	if not _controlling:
		return
	_controlling = false
	_set_spray_visual(false)
	var level := _get_level()
	if level != null:
		level.set_party_switching(true)
		var luca := level.get_node_or_null("Luca")
		if luca != null and luca.has_method("set_control_enabled"):
			luca.call("set_control_enabled", true)


func _update_ui() -> void:
	var level := _get_level()
	if level != null:
		level.update_spray_ui(_pressure, max_pressure, _controlling)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Luca":
		_luca_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Luca":
		_luca_inside = false
		if _controlling:
			_end_control()


func _is_luca_active() -> bool:
	var level := _get_level()
	return level != null and level.is_luca_active()


func _get_level() -> ForestInteriorLevel:
	var cursor: Node = self
	while cursor != null:
		if cursor is ForestInteriorLevel:
			return cursor as ForestInteriorLevel
		cursor = cursor.get_parent()
	return null

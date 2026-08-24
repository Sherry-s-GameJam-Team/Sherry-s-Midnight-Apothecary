class_name TideEye
extends Node2D

signal exposed_changed(exposed: bool)
signal hit_landed(hit_count: int)
signal defeated

@export var hits_required := 3
@export var suction_radius := 430.0
@export var swallow_radius := 74.0
@export var box_swallow_radius := 180.0
@export var suction_strength := 1500.0
@export var exposed_seconds := 4.2
@export var telegraph_seconds := 1.1
@export_range(0.15, 1.0, 0.01) var ground_ellipse_y_scale := 0.42
@export_range(0.1, 3.0, 0.05) var ground_delay_min := 0.35
@export_range(0.1, 3.0, 0.05) var ground_delay_max := 1.1

var hits := 0
var active := false
var exposed := false
var defeated_flag := false
var visual_radius := 18.0
var phase := 0.0
var _swallowed_until: Dictionary = {}

@onready var suction_area: Area2D = $SuctionArea
@onready var suction_shape: CollisionShape2D = $SuctionArea/CollisionShape2D

func _ready() -> void:
	if suction_shape.shape is CircleShape2D:
		(suction_shape.shape as CircleShape2D).radius = suction_radius
	deactivate()

func activate() -> void:
	defeated_flag = false
	active = false
	exposed = false
	hits = 0
	visible = true
	scale = Vector2.ONE
	modulate = Color.WHITE
	# Keep the inactive eye out of potion raycasts; only the landed cyan bottle
	# may schedule its appearance.
	suction_area.collision_layer = 0
	suction_area.monitoring = true
	suction_area.monitorable = true

func deactivate() -> void:
	active = false
	exposed = false
	visible = false
	if suction_area:
		suction_area.collision_layer = 0
		suction_area.monitoring = false
		suction_area.monitorable = false
	queue_redraw()

func receive_potion_hit(hit: Dictionary) -> void:
	var point := hit.get("impact_point", global_position) as Vector2
	if PotionCapabilityResolver.hit_has_capability(hit, &"flow_control"):
		bait_with_water(point)
	elif PotionCapabilityResolver.hit_has_capability(hit, &"purify_strong"):
		_damage_if_exposed()

func apply_potion_effect(_effect_id: StringName, _context: Dictionary) -> void:
	# Direct hits carry PotionData, so this boss intentionally reacts only to
	# pharmacological capabilities rather than generic splash combat effects.
	pass

func bait_with_water(world_position: Vector2) -> void:
	if defeated_flag or active:
		return
	# The bottle must have broken on the ground before the eye reacts. The short,
	# random pause gives the impact room to read as the source of the disturbance.
	await get_tree().create_timer(randf_range(ground_delay_min, ground_delay_max)).timeout
	if defeated_flag or active:
		return
	global_position = world_position
	active = true
	exposed = false
	visual_radius = 18.0
	visible = true
	suction_area.collision_layer = 1
	_shake_camera()
	var tween := create_tween()
	tween.tween_method(_set_visual_radius, 18.0, 110.0, telegraph_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	if defeated_flag or not active:
		return
	exposed = true
	exposed_changed.emit(true)
	await get_tree().create_timer(exposed_seconds).timeout
	if active and not defeated_flag and exposed:
		_close()

func _physics_process(delta: float) -> void:
	if not active or defeated_flag:
		return
	for body: Node2D in suction_area.get_overlapping_bodies():
		var delta_to_eye := global_position - body.global_position
		var distance := maxf(delta_to_eye.length(), 30.0)
		var force := delta_to_eye.normalized() * suction_strength * clampf(1.0 - distance / suction_radius, 0.0, 1.0) * (1.15 if exposed else 0.55)
		if body is CharacterBody2D:
			(body as CharacterBody2D).velocity += force * delta
			if exposed and distance <= swallow_radius:
				_swallow_player(body as CharacterBody2D)
		elif body is RigidBody2D:
			(body as RigidBody2D).apply_central_force(force)
			if exposed and distance <= box_swallow_radius and body.is_in_group("lake_boss_push_boxes"):
				body.queue_free()
				_damage_if_exposed()

func _process(delta: float) -> void:
	phase += delta * (4.5 if active else 1.0)
	if visible:
		queue_redraw()

func _swallow_player(player: CharacterBody2D) -> void:
	var id := player.get_instance_id()
	var now := Time.get_ticks_msec()
	if int(_swallowed_until.get(id, 0)) > now:
		return
	_swallowed_until[id] = now + 1500
	var runtime := _find_day_runtime()
	if runtime != null:
		runtime.apply_player_damage(10, &"tide_eye_swallow")
	player.global_position = global_position + Vector2(-260.0, -110.0)
	player.velocity = Vector2(-420.0, -260.0)

func _damage_if_exposed() -> void:
	if not exposed or defeated_flag:
		return
	hits += 1
	exposed = false
	hit_landed.emit(hits)
	_flash_hit()
	if hits >= hits_required:
		_defeat()
	else:
		_close()

func _close() -> void:
	if not active:
		return
	exposed = false
	exposed_changed.emit(false)
	var tween := create_tween()
	tween.tween_method(_set_visual_radius, visual_radius, 4.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: active = false)

func _defeat() -> void:
	defeated_flag = true
	active = false
	exposed = false
	exposed_changed.emit(false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.05, 0.05), 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.75)
	await tween.finished
	deactivate()
	defeated.emit()

func _draw() -> void:
	if not active or defeated_flag:
		return
	# The eye opens along the floor at the potion impact point: compressing the
	# complete script-drawn vortex vertically keeps it grounded rather than a
	# floating circular sprite.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, ground_ellipse_y_scale))
	var radius := visual_radius * (1.0 + sin(phase * 2.0) * 0.06)
	draw_circle(Vector2.ZERO, radius * 1.16, Color(0.03, 0.18, 0.22, 0.22))
	draw_circle(Vector2.ZERO, radius, Color(0.004, 0.009, 0.015, 0.98))
	draw_circle(Vector2.ZERO, radius * 0.60, Color.BLACK)
	for index in range(5):
		var ring_radius := radius + 14.0 + index * 16.0 + sin(phase + index) * 7.0
		draw_arc(Vector2.ZERO, ring_radius, phase * (0.34 + index * 0.08), phase * (0.34 + index * 0.08) + PI * 1.25, 48, Color(0.10, 0.86, 0.92, 0.42 - index * 0.065), 4.0 - index * 0.5, true)
	if exposed:
		draw_circle(Vector2.ZERO, radius * 0.21, Color(0.30, 1.0, 1.0, 0.94))
		draw_circle(Vector2.ZERO, radius * 0.10, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _set_visual_radius(value: float) -> void:
	visual_radius = value
	queue_redraw()

func _flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.35, 1.0, 1.0, 1.0), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.18)

func _shake_camera() -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player == null:
		return
	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return
	var origin := camera.offset
	var tween := create_tween()
	for index in range(7):
		var x := 9.0 if index % 2 == 0 else -9.0
		tween.tween_property(camera, "offset", origin + Vector2(x, 4.0), 0.055)
	tween.tween_property(camera, "offset", origin, 0.1)

func _find_day_runtime() -> Node:
	var current: Node = self
	while current != null:
		if current.has_method("apply_player_damage"):
			return current
		current = current.get_parent()
	return null

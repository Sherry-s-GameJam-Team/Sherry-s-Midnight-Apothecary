class_name SeraphWeakpoint
extends Area2D

signal weakpoint_purified(weakpoint: SeraphWeakpoint)

@export var point_radius := 24.0
@export var is_core := false

@onready var visual_core: Polygon2D = get_node_or_null("VisualCore")
@onready var visual_glow: Polygon2D = get_node_or_null("VisualGlow")
@onready var particles: CPUParticles2D = get_node_or_null("Particles")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

var _active := true


func _ready() -> void:
	add_to_group("seraph_weakpoint")
	add_to_group("forest_mud")
	collision_layer = 3
	collision_mask = 1
	_build_visuals()


func _build_visuals() -> void:
	if visual_core == null:
		visual_core = get_node_or_null("VisualCore")
	if visual_glow == null:
		visual_glow = get_node_or_null("VisualGlow")
	if particles == null:
		particles = get_node_or_null("Particles")
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")

	if visual_core != null:
		visual_core.polygon = _make_circle_polygon(point_radius * 0.6, 16)
		visual_core.color = Color(0.85, 1.0, 0.95, 0.95)
	if visual_glow != null:
		visual_glow.polygon = _make_circle_polygon(point_radius, 20)
		visual_glow.color = Color(0.3, 0.85, 0.75, 0.45)
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = point_radius


func _make_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(segments):
		var angle := float(i) / float(segments) * TAU
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts


func is_active() -> bool:
	return _active


func set_active(active: bool) -> void:
	_active = active
	visible = active
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not active)
	if particles != null:
		particles.emitting = active


func apply_potion_effect(effect_id: StringName, context: Dictionary = {}) -> void:
	if not _active:
		return
	if effect_id == &"purify" or effect_id == &"purification":
		purify()


func apply_potion_purify(_context: Dictionary = {}) -> void:
	if not _active:
		return
	purify()


func receive_potion_hit(hit: Dictionary) -> void:
	if not _active:
		return
	if PotionCapabilityResolver.hit_has_capability(hit, &"purify_strong"):
		purify()


func purify() -> void:
	if not _active:
		return
	_active = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if particles != null:
		particles.emitting = false
	weakpoint_purified.emit(self)

	# Play bursting flash animation
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.8, 1.8), 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween.finished
	visible = false
	scale = Vector2.ONE
	modulate.a = 1.0


func reset_point() -> void:
	scale = Vector2.ONE
	modulate.a = 1.0
	set_active(true)

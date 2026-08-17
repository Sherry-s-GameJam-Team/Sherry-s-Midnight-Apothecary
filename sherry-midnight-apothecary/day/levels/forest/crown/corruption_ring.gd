class_name CorruptionRing
extends Node2D

signal ring_shattered(ring: CorruptionRing)

@export var ring_radius := 140.0
@export var line_width := 8.0
@export var rotation_speed := 0.8
@export var ring_color := Color(0.35, 0.05, 0.25, 0.85)
@export var glow_color := Color(0.7, 0.1, 0.35, 0.4)
@export var point_count := 2
@export var phase1_mode := false
@export var max_stability := 3

var _stability := 3
var _broken := false
var _weakpoints: Array[SeraphWeakpoint] = []


func _ready() -> void:
	_stability = max_stability
	_setup_ring()


func _process(delta: float) -> void:
	if not _broken:
		rotation += rotation_speed * delta


func _draw() -> void:
	if _broken:
		return
	# Draw outer glow arc
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, glow_color, line_width + 6.0, true)
	# Draw main ring
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 48, ring_color, line_width, true)
	# Draw secondary magical dashes
	for i in range(8):
		var a1 := float(i) / 8.0 * TAU
		var a2 := a1 + 0.25
		draw_arc(Vector2.ZERO, ring_radius - 8.0, a1, a2, 8, Color(0.9, 0.2, 0.5, 0.6), 2.0, true)


func _setup_ring() -> void:
	queue_redraw()
	_weakpoints.clear()
	for child in get_children():
		if child is SeraphWeakpoint:
			var wp := child as SeraphWeakpoint
			wp.weakpoint_purified.connect(_on_weakpoint_purified)
			_weakpoints.append(wp)


func spawn_weakpoints_at_radius(count: int, offset_angle := 0.0) -> void:
	# Clear any previous child weakpoints
	for wp in _weakpoints:
		if is_instance_valid(wp):
			wp.queue_free()
	_weakpoints.clear()

	for i in range(count):
		var angle := offset_angle + float(i) / float(count) * TAU
		var pos := Vector2(cos(angle), sin(angle)) * ring_radius
		var wp := _create_weakpoint_node()
		wp.position = pos
		add_child(wp)
		wp.weakpoint_purified.connect(_on_weakpoint_purified)
		_weakpoints.append(wp)
	queue_redraw()


func _create_weakpoint_node() -> SeraphWeakpoint:
	var wp := SeraphWeakpoint.new()
	wp.name = "Weakpoint"
	wp.collision_layer = 3
	wp.collision_mask = 1

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 24.0
	col.shape = circle
	wp.add_child(col)

	var core := Polygon2D.new()
	core.name = "VisualCore"
	wp.add_child(core)

	var glow := Polygon2D.new()
	glow.name = "VisualGlow"
	wp.add_child(glow)

	var part := CPUParticles2D.new()
	part.name = "Particles"
	part.amount = 8
	part.lifetime = 0.6
	part.spread = 180.0
	part.gravity = Vector2.ZERO
	part.initial_velocity_min = 10.0
	part.initial_velocity_max = 30.0
	part.scale_amount_min = 1.5
	part.scale_amount_max = 3.0
	part.color = Color(0.5, 0.95, 0.9, 0.8)
	wp.add_child(part)

	return wp


func receive_potion_hit(hit: Dictionary) -> void:
	if _broken:
		return
	var pid := StringName(str(hit.get("potion_id", "")))
	var potion_obj: PotionData = hit.get("potion") as PotionData
	var main_effect := potion_obj.main_effect_id if potion_obj != null else &""
	if pid == &"purification_potion" or pid == &"purify" or main_effect == &"purify":
		apply_hit()


func apply_potion_effect(effect_id: StringName, _context: Dictionary = {}) -> void:
	if _broken:
		return
	if effect_id == &"purify" or effect_id == &"purification":
		apply_hit()


func apply_hit() -> void:
	if _broken:
		return
	_stability -= 1
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.08)
	tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	if _stability <= 0:
		shatter()


func _on_weakpoint_purified(_wp: SeraphWeakpoint) -> void:
	# Check if all weakpoints are cleared
	var all_cleared := true
	for p in _weakpoints:
		if is_instance_valid(p) and p.is_active():
			all_cleared = false
			break
	if all_cleared:
		shatter()


func shatter() -> void:
	if _broken:
		return
	_broken = true
	ring_shattered.emit(self)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	visible = false


func reset_ring() -> void:
	_broken = false
	_stability = max_stability
	scale = Vector2.ONE
	modulate = Color.WHITE
	visible = true
	for wp in _weakpoints:
		if is_instance_valid(wp):
			wp.reset_point()
	queue_redraw()

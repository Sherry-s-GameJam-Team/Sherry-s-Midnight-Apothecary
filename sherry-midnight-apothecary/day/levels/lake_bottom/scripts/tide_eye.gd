extends Node2D
class_name TideEye

signal exposed_changed(exposed: bool)
signal defeated

@export var hits_required := 3
@export var suction_radius := 430.0
@export var suction_strength := 1500.0
@export var exposed_seconds := 4.2
@export var telegraph_seconds := 1.1

var hits := 0
var exposed := false
var active := false
var defeated_flag := false
var phase := 0.0
var visual_radius := 24.0
var target_position := Vector2.ZERO
var bodies: Array[Node] = []

@onready var suction_area: Area2D = $SuctionArea
@onready var suction_shape: CollisionShape2D = $SuctionArea/CollisionShape2D

func _ready() -> void:
	if suction_shape and suction_shape.shape is CircleShape2D:
		suction_shape.shape.radius = suction_radius
	suction_area.body_entered.connect(func(b): if b not in bodies: bodies.append(b))
	suction_area.body_exited.connect(func(b): bodies.erase(b))
	set_process(true)
	set_physics_process(true)
	queue_redraw()

func set_hits_required(value: int) -> void:
	hits_required = max(1, value)

func bait_with_water(world_position: Vector2) -> void:
	if defeated_flag or active:
		return
	target_position = world_position
	active = true
	exposed = false
	global_position = world_position
	visual_radius = 18.0
	queue_redraw()
	var tween := create_tween()
	tween.tween_method(_set_visual_radius, 18.0, 110.0, telegraph_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	exposed = true
	exposed_changed.emit(true)
	await get_tree().create_timer(exposed_seconds).timeout
	if defeated_flag:
		return
	exposed = false
	exposed_changed.emit(false)
	var close_tween := create_tween()
	close_tween.tween_method(_set_visual_radius, visual_radius, 5.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await close_tween.finished
	active = false
	queue_redraw()

func receive_potion_hit(hit: Dictionary) -> void:
	var point: Vector2 = hit.get("impact_point", global_position)
	var potion_id: StringName = hit.get("potion_id", &"")
	_handle_potion_bait(point, potion_id)

func apply_potion_effect(effect_id: StringName, context: Dictionary) -> void:
	var point: Vector2 = context.get("impact_point", global_position)
	_handle_potion_bait(point, effect_id)

func _handle_potion_bait(point: Vector2, _source_id: StringName) -> void:
	if defeated_flag or active:
		return
	var level := _find_level()
	if level and level.has_method("can_bait_tide_eye") and not level.can_bait_tide_eye():
		if level.has_method("_set_hint"):
			level._set_hint("先找到旧旅门维护站里的大司鱼。")
		return
	bait_with_water(point)
	if level and level.has_method("on_tide_eye_baited"):
		level.on_tide_eye_baited(point)

func _find_level() -> Node:
	var n: Node = self
	while n:
		if n.has_method("on_level_entered") or n.has_method("try_bait_with_potion"):
			return n
		n = n.get_parent()
	return null

func try_purify(origin: Vector2, aim_angle: float, max_range := 1600.0, angle_tolerance := 0.20) -> bool:
	if defeated_flag or not exposed:
		return false
	var to_eye := global_position - origin
	if to_eye.length() > max_range:
		return false
	var aim_dir := Vector2.RIGHT.rotated(aim_angle)
	var target_angle := aim_dir.angle_to(to_eye.normalized())
	if abs(target_angle) > angle_tolerance:
		return false
	hits += 1
	_flash_hit()
	exposed = false
	exposed_changed.emit(false)
	if hits >= hits_required:
		_defeat()
	else:
		active = false
	return true

func _physics_process(delta: float) -> void:
	if not active or defeated_flag:
		return
	var strength_mult := 1.15 if exposed else 0.55
	for body in bodies.duplicate():
		if not is_instance_valid(body):
			bodies.erase(body)
			continue
		var node_2d := body as Node2D
		if node_2d == null:
			continue
		var d: Vector2 = global_position - node_2d.global_position
		var dist: float = max(d.length(), 40.0)
		var weight: float = clamp(1.0 - dist / suction_radius, 0.0, 1.0)
		var force: Vector2 = d.normalized() * suction_strength * weight * strength_mult
		if body is CharacterBody2D:
			(body as CharacterBody2D).velocity += force * delta
		elif body is RigidBody2D:
			(body as RigidBody2D).apply_central_force(force)

func _process(delta: float) -> void:
	phase += delta * (4.5 if active else 1.0)
	if active:
		queue_redraw()

func _draw() -> void:
	if defeated_flag:
		return
	if not active:
		draw_circle(Vector2.ZERO, 7.0, Color(0.02, 0.08, 0.09, 0.40))
		return
	var pulse := 1.0 + sin(phase * 2.0) * 0.05
	var r := visual_radius * pulse
	draw_circle(Vector2.ZERO, r, Color(0.005, 0.01, 0.015, 0.97))
	draw_circle(Vector2.ZERO, r * 0.62, Color(0.0, 0.0, 0.0, 1.0))
	for i in range(4):
		var rr := r + 18.0 + i * 17.0 + sin(phase + i) * 8.0
		draw_arc(Vector2.ZERO, rr, phase * (0.35 + i * 0.08), phase * (0.35 + i * 0.08) + PI * 1.3, 48, Color(0.18, 0.95, 0.98, 0.42 - i * 0.07), 4.0 - i * 0.5, true)
	if exposed:
		draw_circle(Vector2.ZERO, r * 0.22, Color(0.30, 1.0, 1.0, 0.92))
		draw_circle(Vector2.ZERO, r * 0.11, Color.WHITE)

func _set_visual_radius(value: float) -> void:
	visual_radius = value
	queue_redraw()

func _flash_hit() -> void:
	var old := modulate
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.35, 1.0, 1.0, 1.0), 0.08)
	tween.tween_property(self, "modulate", old, 0.18)

func _defeat() -> void:
	defeated_flag = true
	active = false
	exposed = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(0.05, 0.05), 0.75).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.75)
	await tween.finished
	visible = false
	defeated.emit()

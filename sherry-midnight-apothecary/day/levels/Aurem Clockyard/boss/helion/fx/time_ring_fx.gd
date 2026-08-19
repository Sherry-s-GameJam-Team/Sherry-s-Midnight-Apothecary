extends Node2D
class_name HelionTimeRingFX

var current_radius: float = 0.0
var max_radius: float = 600.0
var _damage: int = 1
var is_active: bool = false
var has_hit_player: bool = false

var area: Area2D
var polygon_shape: CollisionPolygon2D

func _ready():
	area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1 # Player layer
	add_child(area)
	
	polygon_shape = CollisionPolygon2D.new()
	area.add_child(polygon_shape)
	
	area.body_entered.connect(_on_body_entered)

func spawn_ring(center: Vector2, damage: int):
	global_position = center
	_damage = damage
	current_radius = 0.0
	is_active = true
	has_hit_player = false
	
	var tween = create_tween()
	tween.tween_property(self, "current_radius", max_radius, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(ring_finished)

func _process(_delta):
	if is_active:
		update_ring_shape()
		queue_redraw()

func update_ring_shape():
	var points = PackedVector2Array()
	var points_inner = PackedVector2Array()
	var segments = 32
	var r_outer = current_radius + 20.0
	var r_inner = max(0.0, current_radius - 20.0)
	
	for i in range(segments + 1):
		var angle = i * TAU / segments
		points.append(Vector2(cos(angle), sin(angle)) * r_outer)
		points_inner.append(Vector2(cos(angle), sin(angle)) * r_inner)
	
	points_inner.reverse()
	points.append_array(points_inner)
	polygon_shape.polygon = points

func _draw():
	if current_radius > 0:
		draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, Color(1, 0.8, 0.2, 0.8), 40.0)

func _on_body_entered(body: Node2D):
	if not is_active or has_hit_player:
		return
	
	if body.is_in_group("player") or body.name == "Player":
		if body.global_position.y < global_position.y - 60:
			return # Player jumped over
			
		has_hit_player = true
		apply_damage(body)

func apply_damage(_body: Node2D):
	var node = self
	while node:
		if node.has_method("apply_player_damage"):
			node.apply_player_damage(_damage, self)
			return
		elif node.has_method("apply_fall_or_hazard_damage"):
			node.apply_fall_or_hazard_damage(_damage, self)
			return
		node = node.get_parent()

func ring_peak():
	var cam = get_tree().get_first_node_in_group("camera")
	if cam and cam is Camera2D:
		cam.offset = Vector2(randf_range(-10, 10), randf_range(-10, 10))
		var tween = create_tween()
		tween.tween_property(cam, "offset", Vector2.ZERO, 0.2)
	# Also trigger CoreGlow max if needed depending on parent

func ring_finished():
	is_active = false
	area.queue_free()
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)

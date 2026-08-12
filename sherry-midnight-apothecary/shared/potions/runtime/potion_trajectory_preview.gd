class_name PotionTrajectoryPreview
extends Node2D

var _line: Line2D
var _impact: Polygon2D


func _ready() -> void:
	top_level = true
	_line = Line2D.new()
	_line.width = 4.0
	_line.default_color = Color(0.75, 0.92, 1.0, 0.88)
	_line.antialiased = true
	add_child(_line)
	_impact = Polygon2D.new()
	_impact.polygon = PackedVector2Array([Vector2(0, -8), Vector2(8, 0), Vector2(0, 8), Vector2(-8, 0)])
	_impact.color = Color(1.0, 0.78, 0.36, 0.95)
	add_child(_impact)
	hide_preview()


func update_preview(origin: Vector2, initial_velocity: Vector2, tuning: PotionThrowTuning, exclude: Array[RID]) -> void:
	if not is_inside_tree():
		return
	global_position = Vector2.ZERO
	var points := PackedVector2Array([origin])
	var position := origin
	var velocity := initial_velocity
	var elapsed := 0.0
	var hit_point := Vector2.ZERO
	var did_hit := false
	var space := get_world_2d().direct_space_state
	var projectile_shape := CircleShape2D.new()
	projectile_shape.radius = tuning.projectile_radius
	while points.size() < tuning.trajectory_max_points and elapsed < tuning.trajectory_max_time:
		velocity.y += tuning.projectile_gravity * tuning.trajectory_step
		var next_position := position + velocity * tuning.trajectory_step
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = projectile_shape
		query.transform = Transform2D(0.0, position)
		query.motion = next_position - position
		query.collision_mask = tuning.projectile_collision_mask
		query.exclude = exclude
		query.collide_with_areas = true
		query.collide_with_bodies = true
		var motion_fractions := space.cast_motion(query)
		if not motion_fractions.is_empty() and motion_fractions[0] < 1.0:
			hit_point = position + (next_position - position) * motion_fractions[0]
			points.append(hit_point)
			did_hit = true
			break
		points.append(next_position)
		position = next_position
		elapsed += tuning.trajectory_step
	_line.points = points
	_line.visible = true
	_impact.visible = did_hit
	_impact.position = hit_point
	visible = true


func hide_preview() -> void:
	visible = false
	if _line != null:
		_line.clear_points()

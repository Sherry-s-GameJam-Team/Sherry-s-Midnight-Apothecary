extends Camera2D

## Camera limits follow the editable inner edges of the two world barriers.
@export_node_path("CollisionShape2D") var left_barrier_path: NodePath
@export_node_path("CollisionShape2D") var right_barrier_path: NodePath


func _ready() -> void:
	_sync_limits()


func _sync_limits() -> void:
	limit_left = roundi(_inner_edge(left_barrier_path, true))
	limit_right = roundi(_inner_edge(right_barrier_path, false))


func _inner_edge(barrier_path: NodePath, is_left: bool) -> float:
	var collision_shape := get_node_or_null(barrier_path) as CollisionShape2D
	if collision_shape == null or not collision_shape.shape is RectangleShape2D:
		push_error("camera barrier is missing or is not rectangular: %s" % barrier_path)
		return 0.0
	var rectangle := collision_shape.shape as RectangleShape2D
	var half_width := rectangle.size.x * 0.5
	return collision_shape.global_position.x + half_width if is_left else collision_shape.global_position.x - half_width

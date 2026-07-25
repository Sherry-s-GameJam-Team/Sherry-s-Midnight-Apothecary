extends Node2D

signal destination_changed(from_node: String, to_node: String, from_index: int, to_index: int)
signal route_progress_changed(from_node: String, to_node: String, from_index: int, to_index: int, progress: float)
signal route_return_finished()

const BG_TEXTURE_PATH := "res://game/main/scenes/doorchanger/pic/BG.png"
const DETAIL_TEXTURE_PATH := "res://game/main/scenes/doorchanger/pic/detail.png"
const ROUTE_TEXTURE_PATH := "res://game/main/scenes/doorchanger/pic/map.png"
const ROCKER_TEXTURE_PATH := "res://game/main/scenes/doorchanger/pic/rocker.png"
const ROUTE_MASK_SHADER_PATH := "res://game/main/scenes/doorchanger/route_window_mask.gdshader"
const OVERLAY_WINDOW_CENTER := Vector2(626.5, 314.5)
const OVERLAY_WHEEL_CENTER := Vector2(626.5, 626.5)
const ROCKER_POSITION_OFFSET := Vector2(2.012, 50)
const ROCKER_PIVOT_OFFSET := Vector2(71.0, 71.0)
const WINDOW_RADIUS := 229.5
const DEFAULT_MARKER_POSITIONS := {
	"home": Vector2(-426.0, 18.0),
	"point1": Vector2(-265.0, 17.0),
	"point2": Vector2(-77.0, -9.0),
	"point3": Vector2(99.0, -11.0),
	"point4": Vector2(245.0, -10.0),
	"point5": Vector2(420.0, -12.0),
}

@export var view_center := Vector2(512, 512)
@export var move_speed := 86.6667
@export var magnet_radius := 24.0
@export var magnet_strength := 240.0
@export var snap_distance := 2.0
@export var route_root_path: NodePath
@export var player_marker_path: NodePath
@export var bg_path: NodePath
@export var detail_path: NodePath
@export var rocker_path: NodePath
@export var rocker_move_per_radian := 9.0
@export var keyboard_rocker_slow_factor := 1.0
@export var rocker_drag_radius := 170.0

var path_nodes := ["home", "point1", "point2", "point3", "point4", "point5"]
var current_index := 0
var node_markers := {}
var path_distances: Array[float] = []
var path_length := 0.0
var current_distance := 0.0

var route_root: Node2D = null
var player_marker: Node2D = null
var bg: Sprite2D = null
var detail: Sprite2D = null
var route_mask: Sprite2D = null
var route_map: Sprite2D = null
var rocker: Node2D = null
var rocker_sprite: Sprite2D = null
var dragging_rocker := false
var is_returning_to_start := false
var return_target_index := -1
var last_progress_from_index := -1
var last_progress_to_index := -1
var last_route_progress := -1.0


func _ready() -> void:
	_resolve_scene_nodes()
	_collect_node_markers()
	_rebuild_path_distances()

	current_index = clampi(current_index, 0, path_nodes.size() - 1)
	current_distance = _distance_for_index(current_index)
	_apply_transform()
	_emit_route_progress_if_changed(true)


func set_current_node(node_name: String) -> void:
	var target_index := path_nodes.find(node_name)
	if target_index == -1:
		return

	current_index = target_index
	is_returning_to_start = false
	return_target_index = -1
	if path_distances.is_empty():
		return

	current_distance = _distance_for_index(current_index)
	_apply_transform()
	_emit_route_progress_if_changed(true)


func _process(delta: float) -> void:
	if route_root == null or player_marker == null or path_distances.is_empty():
		return

	var input_direction := _held_direction()
	if is_returning_to_start:
		_return_to_start(delta)
	elif dragging_rocker:
		pass
	elif input_direction != 0:
		_move_while_held(input_direction, delta)
	else:
		_apply_node_magnet(delta)

	_apply_transform()
	_emit_route_progress_if_changed(false)


func _unhandled_input(event: InputEvent) -> void:
	if rocker == null:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		var mouse_position := get_global_mouse_position()
		if is_returning_to_start:
			_mark_input_handled()
		elif mouse_event.pressed and _is_mouse_near_rocker(mouse_position):
			dragging_rocker = true
			_apply_rocker_drag(mouse_position)
			_mark_input_handled()
		elif dragging_rocker:
			dragging_rocker = false
			_mark_input_handled()
	elif event is InputEventMouseMotion and dragging_rocker and not is_returning_to_start:
		_apply_rocker_drag(get_global_mouse_position())
		_mark_input_handled()
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_A or key_event.keycode == KEY_D:
			_mark_input_handled()


func _move_while_held(direction: int, delta: float) -> void:
	if is_returning_to_start:
		return

	var target_index := _adjacent_node_index(direction)
	if target_index == -1:
		return

	var previous_distance := current_distance
	var target_distance := _distance_for_index(target_index)
	current_distance = clampf(current_distance + move_speed * delta * float(direction), 0.0, path_length)

	if absf(current_distance - target_distance) <= magnet_radius:
		current_distance = move_toward(current_distance, target_distance, magnet_strength * delta)

	if _has_reached_target_distance(direction, target_distance):
		current_distance = target_distance
		_set_current_index(target_index)

	_rotate_rocker_for_distance_delta(current_distance - previous_distance)


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _apply_rocker_drag(global_mouse_position: Vector2) -> void:
	if is_returning_to_start:
		return

	var target_angle := _rocker_angle_to(global_mouse_position)
	var angle_delta := wrapf(target_angle - rocker.rotation, -PI, PI)

	if is_zero_approx(angle_delta):
		return

	rocker.rotation += angle_delta
	current_distance = clampf(current_distance + angle_delta * rocker_move_per_radian, 0.0, path_length)
	_update_current_index_from_distance()


func _apply_node_magnet(delta: float) -> void:
	var nearest_index := _nearest_node_index()
	if nearest_index == -1:
		return

	var nearest_distance := _distance_for_index(nearest_index)
	if absf(current_distance - nearest_distance) > magnet_radius:
		return

	current_distance = move_toward(current_distance, nearest_distance, magnet_strength * delta)
	if absf(current_distance - nearest_distance) <= snap_distance:
		current_distance = nearest_distance
		_set_current_index(nearest_index)


func request_close() -> bool:
	if _route_progress() <= 0.001:
		return true

	is_returning_to_start = true
	dragging_rocker = false
	return_target_index = current_index
	return false


func _return_to_start(delta: float) -> void:
	if return_target_index < 0:
		return_target_index = current_index

	var target_distance := _distance_for_index(return_target_index)
	current_distance = move_toward(current_distance, target_distance, magnet_strength * delta)
	if absf(current_distance - target_distance) <= snap_distance:
		current_distance = target_distance
		is_returning_to_start = false
		return_target_index = -1
		_set_current_index(_nearest_node_index())
		_emit_route_progress_if_changed(true)
		route_return_finished.emit()


func _apply_transform() -> void:
	var map_position := _map_position_for_distance(current_distance)
	var route_view_center := _view_center_in_route_parent()

	player_marker.position = view_center
	route_root.rotation = 0.0
	route_root.position = route_view_center - map_position
	_update_route_map_mask(map_position)


func _set_current_index(target_index: int) -> void:
	if target_index == current_index:
		return

	var from_name: String = path_nodes[current_index]
	var to_name: String = path_nodes[target_index]
	print("MapWheel move: ", from_name, " -> ", to_name)
	print("MapWheel index: ", current_index, " -> ", target_index)
	route_progress_changed.emit(from_name, to_name, current_index, target_index, 1.0)
	destination_changed.emit(from_name, to_name, current_index, target_index)
	current_index = target_index
	_emit_route_progress_if_changed(true)


func _update_current_index_from_distance() -> void:
	var nearest_index := _nearest_node_index()
	if nearest_index == -1:
		return

	var nearest_distance := _distance_for_index(nearest_index)
	if absf(current_distance - nearest_distance) <= snap_distance:
		current_distance = nearest_distance
		_set_current_index(nearest_index)
		return

	while current_index < path_nodes.size() - 1:
		var next_index := current_index + 1
		if current_distance < _distance_for_index(next_index) - snap_distance:
			break
		_set_current_index(next_index)

	while current_index > 0:
		var previous_index := current_index - 1
		if current_distance > _distance_for_index(previous_index) + snap_distance:
			break
		_set_current_index(previous_index)


func _held_direction() -> int:
	var direction := 0
	if Input.is_key_pressed(KEY_D):
		direction += 1
	if Input.is_key_pressed(KEY_A):
		direction -= 1
	return direction


func _adjacent_node_index(direction: int) -> int:
	if direction > 0:
		for index in range(path_distances.size()):
			if path_distances[index] > current_distance + snap_distance:
				return index
	else:
		for index in range(path_distances.size() - 1, -1, -1):
			if path_distances[index] < current_distance - snap_distance:
				return index
	return -1


func _has_reached_target_distance(direction: int, target_distance: float) -> bool:
	if direction > 0:
		return current_distance >= target_distance - snap_distance
	return current_distance <= target_distance + snap_distance


func _nearest_node_index() -> int:
	var nearest_index := -1
	var nearest_distance_delta := INF

	for index in range(path_distances.size()):
		var distance_delta := absf(current_distance - path_distances[index])
		if distance_delta < nearest_distance_delta:
			nearest_distance_delta = distance_delta
			nearest_index = index

	return nearest_index


func _emit_route_progress_if_changed(force: bool) -> void:
	var segment := _route_progress_segment()
	var from_index := int(segment["from_index"])
	var to_index := int(segment["to_index"])
	var progress := float(segment["progress"])

	if (
		not force
		and from_index == last_progress_from_index
		and to_index == last_progress_to_index
		and absf(progress - last_route_progress) <= 0.001
	):
		return

	last_progress_from_index = from_index
	last_progress_to_index = to_index
	last_route_progress = progress

	if from_index == -1 or to_index == -1:
		route_progress_changed.emit("", "", -1, -1, 0.0)
		return

	route_progress_changed.emit(
		String(path_nodes[from_index]),
		String(path_nodes[to_index]),
		from_index,
		to_index,
		progress
	)


func _route_progress() -> float:
	return float(_route_progress_segment()["progress"])


func _route_progress_segment() -> Dictionary:
	if path_distances.is_empty() or current_index < 0 or current_index >= path_distances.size():
		return {
			"from_index": -1,
			"to_index": -1,
			"progress": 0.0,
		}

	var start_distance := _distance_for_index(current_index)
	if absf(current_distance - start_distance) <= snap_distance:
		return {
			"from_index": -1,
			"to_index": -1,
			"progress": 0.0,
		}

	var direction := 1 if current_distance > start_distance else -1
	var target_index := current_index + direction
	if target_index < 0 or target_index >= path_distances.size():
		return {
			"from_index": -1,
			"to_index": -1,
			"progress": 0.0,
		}

	var target_distance := _distance_for_index(target_index)
	var segment_length := absf(target_distance - start_distance)
	var progress := 0.0
	if not is_zero_approx(segment_length):
		progress = absf(current_distance - start_distance) / segment_length

	return {
		"from_index": current_index,
		"to_index": target_index,
		"progress": clampf(progress, 0.0, 1.0),
	}


func _map_position_for_distance(distance: float) -> Vector2:
	if path_nodes.is_empty():
		return Vector2.ZERO

	if distance <= 0.0:
		return _marker_position(0)
	if distance >= path_length:
		return _marker_position(path_nodes.size() - 1)

	for index in range(path_distances.size() - 1):
		var start_distance := path_distances[index]
		var end_distance := path_distances[index + 1]
		if distance <= end_distance:
			var segment_length := end_distance - start_distance
			var t := 0.0 if is_zero_approx(segment_length) else (distance - start_distance) / segment_length
			return _marker_position(index).lerp(_marker_position(index + 1), t)

	return _marker_position(path_nodes.size() - 1)


func _rebuild_path_distances() -> void:
	path_distances.clear()
	path_length = 0.0

	if path_nodes.is_empty():
		return

	path_distances.append(0.0)
	for index in range(1, path_nodes.size()):
		path_length += _marker_position(index - 1).distance_to(_marker_position(index))
		path_distances.append(path_length)


func _distance_for_index(index: int) -> float:
	if index < 0 or index >= path_distances.size():
		return 0.0
	return path_distances[index]


func _marker_position(index: int) -> Vector2:
	var marker := node_markers.get(path_nodes[index]) as Node2D
	return marker.position if marker != null else Vector2.ZERO


func _resolve_scene_nodes() -> void:
	route_root = _get_node_or_default(route_root_path, "RouteRoot") as Node2D
	if route_root == null:
		route_root = Node2D.new()
		route_root.name = "RouteRoot"
		add_child(route_root)
	route_root.z_index = 0
	route_root.rotation = 0.0

	_ensure_route_map()

	player_marker = _get_node_or_default(player_marker_path, "PlayerMarker") as Node2D
	if player_marker == null:
		player_marker = Node2D.new()
		player_marker.name = "PlayerMarker"
		add_child(player_marker)
	player_marker.z_index = 5

	bg = _ensure_sprite(bg_path, "BG", BG_TEXTURE_PATH, -10, self)
	detail = _ensure_sprite(detail_path, "Detail", DETAIL_TEXTURE_PATH, 10, self)
	route_mask = _resolve_route_mask()
	rocker = _ensure_rocker()


func _collect_node_markers() -> void:
	node_markers.clear()

	for node_name in path_nodes:
		var marker := route_root.get_node_or_null(NodePath(node_name)) as Node2D
		if marker == null:
			marker = Node2D.new()
			marker.name = node_name
			marker.position = DEFAULT_MARKER_POSITIONS[node_name]
			route_root.add_child(marker)
		node_markers[node_name] = marker


func _ensure_route_map() -> void:
	route_map = route_root.get_node_or_null("RouteMap") as Sprite2D
	if route_map == null:
		route_map = Sprite2D.new()
		route_map.name = "RouteMap"
		route_root.add_child(route_map)

	route_map.texture = load(ROUTE_TEXTURE_PATH)
	route_map.centered = true
	route_map.z_index = 0
	_ensure_route_map_material()


func _view_center_in_route_parent() -> Vector2:
	var parent_node := route_root.get_parent() as Node2D
	if parent_node == null or parent_node == self:
		return view_center
	return parent_node.to_local(to_global(view_center))


func _resolve_route_mask() -> Sprite2D:
	var parent_sprite := route_root.get_parent() as Sprite2D
	if parent_sprite == null:
		return null

	parent_sprite.texture = load(BG_TEXTURE_PATH)
	parent_sprite.centered = false
	parent_sprite.position = view_center - OVERLAY_WINDOW_CENTER
	parent_sprite.z_index = 0
	parent_sprite.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	return parent_sprite


func _ensure_rocker() -> Node2D:
	var rocker_node := _get_node_or_default(rocker_path, "Rocker") as Node2D
	if rocker_node == null:
		rocker_node = Node2D.new()
		rocker_node.name = "Rocker"
		add_child(rocker_node)

	rocker_node.position = _rocker_center_position()
	rocker_node.z_index = 12

	rocker_sprite = rocker_node.get_node_or_null("Sprite") as Sprite2D
	if rocker_sprite == null:
		rocker_sprite = Sprite2D.new()
		rocker_sprite.name = "Sprite"
		rocker_node.add_child(rocker_sprite)

	rocker_sprite.texture = load(ROCKER_TEXTURE_PATH)
	rocker_sprite.centered = false
	rocker_sprite.position = -ROCKER_PIVOT_OFFSET
	return rocker_node


func _rocker_center_position() -> Vector2:
	return view_center - OVERLAY_WINDOW_CENTER + OVERLAY_WHEEL_CENTER + ROCKER_POSITION_OFFSET


func _is_mouse_near_rocker(global_mouse_position: Vector2) -> bool:
	return rocker.to_local(global_mouse_position).length() <= rocker_drag_radius


func _rocker_angle_to(global_mouse_position: Vector2) -> float:
	return (global_mouse_position - rocker.global_position).angle()


func _rotate_rocker_for_distance_delta(distance_delta: float) -> void:
	if rocker == null or is_zero_approx(distance_delta):
		return
	var slow_factor := maxf(keyboard_rocker_slow_factor, 0.001)
	rocker.rotation += distance_delta / (rocker_move_per_radian * slow_factor)


func _ensure_route_map_material() -> void:
	var shader := load(ROUTE_MASK_SHADER_PATH) as Shader
	if shader == null or route_map == null:
		return

	var shader_material := route_map.material as ShaderMaterial
	if shader_material == null or shader_material.shader != shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		route_map.material = shader_material

	shader_material.set_shader_parameter("window_radius", WINDOW_RADIUS)


func _update_route_map_mask(map_position: Vector2) -> void:
	if route_map == null:
		return

	var shader_material := route_map.material as ShaderMaterial
	if shader_material == null:
		return

	shader_material.set_shader_parameter("window_center", map_position)
	shader_material.set_shader_parameter("window_radius", WINDOW_RADIUS)


func _ensure_sprite(path: NodePath, fallback_name: String, texture_path: String, target_z_index: int, parent: Node) -> Sprite2D:
	var sprite := _get_node_or_default(path, fallback_name) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = fallback_name
		parent.add_child(sprite)

	sprite.texture = load(texture_path)
	sprite.centered = false
	sprite.position = view_center - OVERLAY_WINDOW_CENTER
	sprite.z_index = target_z_index
	return sprite


func _get_node_or_default(path: NodePath, fallback_name: String) -> Node:
	if not str(path).is_empty() and has_node(path):
		return get_node(path)
	return get_node_or_null(fallback_name)

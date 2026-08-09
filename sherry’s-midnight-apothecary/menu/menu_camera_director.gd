class_name MenuCameraDirector
extends Node

signal descent_finished

@export var camera_path: NodePath
@export var start_marker_path: NodePath
@export var cloud_marker_path: NodePath
@export var forest_marker_path: NodePath
@export var roof_marker_path: NodePath
@export var parallax_layer_paths: Array[NodePath] = []
@export var parallax_factors: Array[float] = []
@export_range(0.0, 2.0, 0.05) var descent_delay := 0.35
@export_range(0.1, 10.0, 0.05) var descent_duration := 4.05

var _camera: Camera2D
var _start: Marker2D
var _points: Array[Marker2D] = []
var _layers: Array[Node2D] = []
var _layer_origins: Array[Vector2] = []
var _running := false


func _ready() -> void:
	_camera = get_node(camera_path) as Camera2D
	_start = get_node(start_marker_path) as Marker2D
	_points = [
		get_node(cloud_marker_path) as Marker2D,
		get_node(forest_marker_path) as Marker2D,
		get_node(roof_marker_path) as Marker2D,
	]
	for path: NodePath in parallax_layer_paths:
		var layer := get_node_or_null(path) as Node2D
		if layer != null:
			_layers.append(layer)
			_layer_origins.append(layer.position)
	_camera.global_position = _start.global_position


func play_descent() -> void:
	if _running:
		return
	_running = true
	var tween := create_tween()
	tween.tween_interval(descent_delay)
	tween.tween_method(_set_descent_elapsed_ratio, 0.0, 1.0, descent_duration).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	_set_descent_elapsed_ratio(1.0)
	_running = false
	_sync_parallax()
	descent_finished.emit()


static func ease_uniform_accel_decel(value: float) -> float:
	var elapsed_ratio := clampf(value, 0.0, 1.0)
	if elapsed_ratio < 0.5:
		return 2.0 * elapsed_ratio * elapsed_ratio
	var remaining := 1.0 - elapsed_ratio
	return 1.0 - 2.0 * remaining * remaining


func _set_descent_elapsed_ratio(value: float) -> void:
	var progress := ease_uniform_accel_decel(value)
	_camera.global_position = _position_along_path(progress)


func _position_along_path(progress: float) -> Vector2:
	var path: Array[Marker2D] = [_start]
	path.append_array(_points)
	var total_distance := 0.0
	for index in range(path.size() - 1):
		total_distance += path[index].global_position.distance_to(path[index + 1].global_position)
	if total_distance <= 0.0:
		return _start.global_position
	var target_distance := clampf(progress, 0.0, 1.0) * total_distance
	var travelled := 0.0
	for index in range(path.size() - 1):
		var from := path[index].global_position
		var to := path[index + 1].global_position
		var segment_distance := from.distance_to(to)
		if target_distance <= travelled + segment_distance or index == path.size() - 2:
			var segment_progress := 1.0 if segment_distance <= 0.0 else (target_distance - travelled) / segment_distance
			return from.lerp(to, clampf(segment_progress, 0.0, 1.0))
		travelled += segment_distance
	return path[-1].global_position


func release_camera() -> void:
	# The menu remains in the tree until the bedroom introduction finishes.
	# Relinquish the viewport while the roof fully covers the swap, otherwise
	# this camera keeps rendering the now-hidden menu coordinates as gray.
	_camera.enabled = false


func _process(_delta: float) -> void:
	if _running:
		_sync_parallax()


func _sync_parallax() -> void:
	var travel := _camera.global_position.y - _start.global_position.y
	for index in range(_layers.size()):
		var factor := parallax_factors[index] if index < parallax_factors.size() else 1.0
		_layers[index].position = _layer_origins[index] + Vector2(0.0, travel * (1.0 - factor))

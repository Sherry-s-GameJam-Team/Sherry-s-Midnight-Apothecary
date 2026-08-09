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
	tween.tween_interval(0.35)
	tween.tween_property(_camera, "global_position", _points[0].global_position, 0.85).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.tween_property(_camera, "global_position", _points[1].global_position, 2.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_camera, "global_position", _points[2].global_position, 1.15).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tween.finished
	_running = false
	_sync_parallax()
	descent_finished.emit()


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

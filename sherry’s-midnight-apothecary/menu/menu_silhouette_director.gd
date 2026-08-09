class_name MenuSilhouetteDirector
extends Node

signal bird_flight_finished

@export_node_path("Sprite2D") var tree_path: NodePath
@export_node_path("Sprite2D") var bird_path: NodePath
@export_node_path("Marker2D") var roof_marker_path: NodePath
@export_range(0.0, 200.0, 1.0) var roof_clearance := 20.0
@export_range(0.0, 2.0, 0.05) var bird_delay := 0.2
@export_range(0.1, 5.0, 0.05) var bird_duration := 1.45
@export_range(0.0, 300.0, 1.0) var flight_padding := 64.0

var _tree: Sprite2D
var _bird: Sprite2D
var _roof_marker: Marker2D
var _flight_tween: Tween
var _bird_start_x := 0.0
var _bird_end_x := 0.0
var _flight_progress := 0.0
var _running := false
var _completed := false


func _ready() -> void:
	_tree = get_node_or_null(tree_path) as Sprite2D
	_bird = get_node_or_null(bird_path) as Sprite2D
	_roof_marker = get_node_or_null(roof_marker_path) as Marker2D
	if not _has_valid_layers():
		push_error("MenuSilhouetteDirector requires tree, bird, roof marker, and matching textures.")
		set_process(false)
		return
	get_viewport().size_changed.connect(_layout_layers)
	reset()


func play() -> bool:
	if _running or _completed or not _has_valid_layers():
		return false
	_running = true
	_flight_progress = 0.0
	_layout_layers()
	_bird.visible = false
	_flight_tween = create_tween()
	_flight_tween.tween_interval(bird_delay)
	_flight_tween.tween_callback(func() -> void: _bird.visible = true)
	_flight_tween.tween_method(_set_flight_progress, 0.0, 1.0, bird_duration).set_trans(Tween.TRANS_LINEAR)
	_flight_tween.tween_callback(_finish_flight)
	return true


func reset() -> void:
	if _flight_tween != null and _flight_tween.is_valid():
		_flight_tween.kill()
	_flight_tween = null
	_running = false
	_completed = false
	_flight_progress = 0.0
	if _has_valid_layers():
		_layout_layers()
		_bird.visible = false


func is_running() -> bool:
	return _running


func has_completed() -> bool:
	return _completed


func get_bird_start_x() -> float:
	return _bird_start_x


func get_bird_end_x() -> float:
	return _bird_end_x


func _layout_layers() -> void:
	if not _has_valid_layers():
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	var texture_size := _tree.texture.get_size()
	if viewport_width <= 0.0 or texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var layer_scale := viewport_width / texture_size.x
	var layer_position := Vector2(
		-viewport_width * 0.5,
		_roof_marker.global_position.y - roof_clearance - texture_size.y * layer_scale
	)
	_tree.scale = Vector2.ONE * layer_scale
	_tree.global_position = layer_position
	_bird.scale = _tree.scale
	_bird.global_position.y = layer_position.y
	_bird_start_x = viewport_width * 0.5 + flight_padding
	_bird_end_x = -viewport_width * 0.5 - texture_size.x * layer_scale - flight_padding
	_bird.global_position.x = lerpf(_bird_start_x, _bird_end_x, _flight_progress)


func _set_flight_progress(value: float) -> void:
	_flight_progress = clampf(value, 0.0, 1.0)
	_bird.global_position.x = lerpf(_bird_start_x, _bird_end_x, _flight_progress)


func _finish_flight() -> void:
	_set_flight_progress(1.0)
	_running = false
	_completed = true
	_bird.visible = false
	bird_flight_finished.emit()


func _has_valid_layers() -> bool:
	return (
		_tree != null
		and _bird != null
		and _roof_marker != null
		and _tree.texture != null
		and _bird.texture != null
		and _tree.texture.get_size() == _bird.texture.get_size()
	)

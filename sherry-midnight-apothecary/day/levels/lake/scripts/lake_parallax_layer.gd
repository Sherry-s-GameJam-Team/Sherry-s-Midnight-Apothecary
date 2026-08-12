@tool
class_name LakeParallaxLayer
extends Node2D

@export_range(0.0, 2.0, 0.01) var ratio_x := 0.3
@export_range(0.0, 2.0, 0.01) var ratio_y := 0.3
@export var drift_amplitude := Vector2.ZERO
@export_range(0.1, 60.0, 0.1) var drift_period := 8.0
@export var phase_offset := 0.0

var camera: Camera2D
var _origin_position := Vector2.ZERO
var _origin_camera_position := Vector2.ZERO


func _ready() -> void:
	_origin_position = global_position
	_resolve_camera()
	set_process(not Engine.is_editor_hint())


func setup(target_camera: Camera2D) -> void:
	camera = target_camera
	_origin_position = global_position
	_origin_camera_position = camera.global_position if camera != null else Vector2.ZERO


func _process(_delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		_resolve_camera()
		if camera == null:
			return
	var camera_delta := camera.global_position - _origin_camera_position
	var time := Time.get_ticks_msec() * 0.001
	var phase := TAU * time / maxf(drift_period, 0.1) + phase_offset
	var drift := Vector2(sin(phase), cos(phase * 0.83)) * drift_amplitude
	global_position = _origin_position + Vector2(camera_delta.x * ratio_x, camera_delta.y * ratio_y) + drift


func _resolve_camera() -> void:
	var cameras := get_tree().get_nodes_in_group("lake_transition_camera")
	if cameras.is_empty():
		return
	camera = cameras[0] as Camera2D
	if camera != null:
		_origin_camera_position = camera.global_position


@tool
class_name LakeWaterSurface
extends ColorRect

@export_range(0.0, 1.5, 0.01) var vertical_parallax := 0.35
@export_range(0.0, 30.0, 0.5) var bob_amplitude := 5.0
@export_range(0.1, 30.0, 0.1) var bob_period := 5.0
@export var phase_offset := 0.0

var camera: Camera2D
var _origin_position := Vector2.ZERO
var _origin_camera_y := 0.0


func _ready() -> void:
	_origin_position = position
	_resolve_camera()
	set_process(not Engine.is_editor_hint())


func setup(target_camera: Camera2D) -> void:
	camera = target_camera
	_origin_position = position
	_origin_camera_y = camera.global_position.y if camera != null else 0.0


func _process(_delta: float) -> void:
	if camera == null or not is_instance_valid(camera):
		_resolve_camera()
		if camera == null:
			return
	var time := Time.get_ticks_msec() * 0.001
	var bob := sin(TAU * time / maxf(bob_period, 0.1) + phase_offset) * bob_amplitude
	position = _origin_position + Vector2(0.0, (camera.global_position.y - _origin_camera_y) * vertical_parallax + bob)


func _resolve_camera() -> void:
	var cameras := get_tree().get_nodes_in_group("lake_transition_camera")
	if cameras.is_empty():
		return
	camera = cameras[0] as Camera2D
	if camera != null:
		_origin_camera_y = camera.global_position.y


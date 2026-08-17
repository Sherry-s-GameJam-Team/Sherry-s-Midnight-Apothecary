class_name PotionCameraDirector
extends Node

signal follow_finished

var _temporary_camera: Camera2D
var _original_camera: Camera2D
var _target: Node2D
var _deadline_ms := 0
var _active := false
var _transition_duration := 0.22


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_temporary_camera = Camera2D.new()
	_temporary_camera.name = "PotionFlightCamera"
	_temporary_camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	_temporary_camera.enabled = false
	add_child(_temporary_camera)


func follow(projectile: Node2D, tuning: PotionThrowTuning) -> void:
	if projectile == null or not is_instance_valid(projectile):
		return
	_original_camera = get_viewport().get_camera_2d()
	_target = projectile
	_transition_duration = tuning.camera_transition_duration
	_deadline_ms = Time.get_ticks_msec() + roundi(tuning.camera_follow_max_time * 1000.0)
	if _original_camera != null:
		_temporary_camera.global_position = _original_camera.global_position
		_temporary_camera.zoom = _original_camera.zoom
		_temporary_camera.limit_left = _original_camera.limit_left
		_temporary_camera.limit_right = _original_camera.limit_right
		_temporary_camera.limit_top = _original_camera.limit_top
		_temporary_camera.limit_bottom = _original_camera.limit_bottom
		_temporary_camera.position_smoothing_enabled = false
	_temporary_camera.enabled = true
	_temporary_camera.make_current()
	var target_zoom := _temporary_camera.zoom * tuning.camera_zoom_multiplier
	create_tween().set_ignore_time_scale(true).tween_property(_temporary_camera, "zoom", target_zoom, _transition_duration)
	_active = true


func stop_follow() -> void:
	if not _active:
		return
	_active = false
	_target = null
	if _original_camera != null and is_instance_valid(_original_camera):
		var tween := create_tween().set_ignore_time_scale(true).set_parallel(true)
		tween.tween_property(_temporary_camera, "global_position", _original_camera.global_position, _transition_duration)
		tween.tween_property(_temporary_camera, "zoom", _original_camera.zoom, _transition_duration)
		tween.chain().tween_callback(_finish_return)
	else:
		_finish_return()


func _physics_process(_delta: float) -> void:
	if not _active:
		return
	if _target == null or not is_instance_valid(_target) or Time.get_ticks_msec() >= _deadline_ms:
		stop_follow()
		return
	_temporary_camera.global_position = _target.global_position


func _finish_return() -> void:
	if _original_camera != null and is_instance_valid(_original_camera):
		_original_camera.enabled = true
		_original_camera.make_current()
	_temporary_camera.enabled = false
	follow_finished.emit()


func _exit_tree() -> void:
	if _original_camera != null and is_instance_valid(_original_camera) and _original_camera.is_inside_tree():
		_original_camera.enabled = true
		_original_camera.make_current()

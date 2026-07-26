class_name TownCameraController
extends Node2D

signal transition_finished(mode: int)

enum CameraMode {
	TITLE,
	OUTDOOR,
	INDOOR,
	LAKE_REVEAL,
}

@export_category("Node References")
@export_node_path("Camera2D") var camera_path: NodePath
@export_node_path("CharacterBody2D") var player_path: NodePath
@export_node_path("Marker2D") var interior_camera_center_path: NodePath
@export_node_path("Marker2D") var outdoor_ground_camera_marker_path: NodePath
@export_node_path("Marker2D") var outdoor_upper_camera_marker_path: NodePath

@export_category("Outdoor Camera Bounds")
@export var outdoor_left_bound := 0.0
@export var outdoor_right_bound := 5928.0
@export var horizontal_follow_speed := 9.0

@export_category("Outdoor Vertical Follow")
@export var outdoor_ground_camera_y := 392.0
@export var outdoor_upper_camera_y := 220.0
@export var outdoor_ground_player_y := 627.0
@export var vertical_follow_enter_offset := 120.0
@export var vertical_follow_exit_offset := 90.0
@export var vertical_dead_zone := 24.0
@export_range(0.0, 1.0, 0.01) var vertical_follow_ratio := 0.12
@export var max_ground_vertical_shift := 0.0
@export var vertical_follow_speed := 2.5
@export var vertical_return_speed := 3.5

@export_category("Indoor Camera")
@export_range(0.01, 2.0, 0.01) var interior_zoom_multiplier := 0.75

@export_category("Lake Reveal Camera")
@export var lake_reveal_target_x := 0.0
@export var lake_reveal_zoom := 1.0
@export var lake_reveal_normal_zoom := 1.35
@export var lake_reveal_normal_right_limit := 1830.0
@export var lake_reveal_right_limit := 2999.0
@export var normal_camera_offset_y := 392.0
@export var lake_reveal_camera_offset_y := 392.0

@export_category("Debug")
@export var debug_camera_bounds := false
@export var debug_print_interval := 0.5

var mode := CameraMode.TITLE
var vertical_follow_active := false
var target_position := Vector2.ZERO
var outdoor_zoom := Vector2.ONE

var saved_outdoor_position := Vector2.ZERO
var saved_outdoor_zoom := Vector2.ONE
var saved_outdoor_smoothing_enabled := false
var saved_outdoor_smoothing_speed := 0.0
var saved_outdoor_limits := Rect2()
var saved_outdoor_vertical_follow_active := false

var _outdoor_position_float := Vector2.ZERO
var _transition_tween: Tween = null
var _is_transitioning := false
var _debug_print_time := 0.0
var _lake_reveal_progress := 0.0
var _lake_reveal_active := false

@onready var camera := get_node_or_null(camera_path) as Camera2D
@onready var player := get_node_or_null(player_path) as CharacterBody2D
@onready var interior_camera_center := get_node_or_null(interior_camera_center_path) as Marker2D
@onready var outdoor_ground_camera_marker := get_node_or_null(outdoor_ground_camera_marker_path) as Marker2D
@onready var outdoor_upper_camera_marker := get_node_or_null(outdoor_upper_camera_marker_path) as Marker2D


func _ready() -> void:
	if camera == null or player == null:
		push_error("TownCameraController requires valid camera and player references.")
		set_process(false)
		return

	var preserved_global_position := camera.global_position
	outdoor_zoom = camera.zoom
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.position_smoothing_speed = 0.0
	camera.global_position = preserved_global_position
	_set_camera_physics_interpolation(false)
	target_position = preserved_global_position
	_outdoor_position_float = preserved_global_position
	_refresh_marker_values()

	var viewport := get_viewport()
	if viewport != null:
		viewport.size_changed.connect(_on_viewport_size_changed)


func _process(delta: float) -> void:
	_update_debug(delta)


func _physics_process(delta: float) -> void:
	if camera == null or player == null:
		return

	match mode:
		CameraMode.OUTDOOR:
			if not _is_transitioning:
				_update_outdoor_camera(delta)
		CameraMode.INDOOR:
			if not _is_transitioning:
				_enforce_indoor_lock()
		CameraMode.LAKE_REVEAL:
			_update_lake_reveal_camera()
		CameraMode.TITLE:
			pass


func enter_title_mode(title_position: Vector2) -> void:
	_save_outdoor_state_if_needed()
	cancel_transition()
	mode = CameraMode.TITLE
	vertical_follow_active = false
	camera.top_level = true
	camera.position_smoothing_enabled = false
	target_position = _snap_camera_position(title_position)
	_apply_fixed_view_limits(target_position, camera.zoom)
	camera.global_position = target_position
	_set_camera_physics_interpolation(false)
	camera.force_update_scroll()


func enter_outdoor_mode(restore_immediately := false) -> void:
	cancel_transition()
	_lake_reveal_active = false
	mode = CameraMode.OUTDOOR
	vertical_follow_active = false
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.zoom = outdoor_zoom
	_apply_outdoor_limits()

	var outdoor_target := _calculate_outdoor_target()
	_outdoor_position_float = camera.global_position
	if restore_immediately:
		target_position = outdoor_target
		_outdoor_position_float = outdoor_target
		camera.global_position = _snap_camera_position(outdoor_target)
		_set_camera_physics_interpolation(true)
		camera.force_update_scroll()
		return

	transition_to_target(outdoor_target, outdoor_zoom, 0.55)


func enter_indoor_mode(
	restore_immediately := false,
	target_override := Vector2.ZERO,
	zoom_override := Vector2.ZERO,
	use_override := false
) -> void:
	_save_outdoor_state_if_needed()
	cancel_transition()
	mode = CameraMode.INDOOR
	vertical_follow_active = false
	camera.top_level = true
	camera.position_smoothing_enabled = false

	var indoor_target := target_override if use_override else _indoor_camera_position()
	var indoor_zoom := zoom_override if use_override else outdoor_zoom * interior_zoom_multiplier
	target_position = _snap_camera_position(indoor_target)

	if restore_immediately:
		camera.zoom = indoor_zoom
		_apply_fixed_view_limits(target_position, indoor_zoom)
		camera.global_position = target_position
		_set_camera_physics_interpolation(false)
		camera.force_update_scroll()
		return

	transition_to_target(target_position, indoor_zoom, 0.55)


func transition_to_target(
	new_target_position: Vector2,
	new_target_zoom: Vector2,
	duration: float
) -> void:
	cancel_transition()
	target_position = _snap_camera_position(new_target_position)
	camera.top_level = true
	camera.position_smoothing_enabled = false
	_set_camera_physics_interpolation(false)
	_apply_transition_limits(camera.global_position, target_position, camera.zoom, new_target_zoom)

	if duration <= 0.0:
		camera.zoom = new_target_zoom
		camera.global_position = target_position
		camera.force_update_scroll()
		transition_finished.emit(mode)
		return

	_is_transitioning = true
	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_SINE)
	_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_method(
		_set_camera_position_from_tween,
		camera.global_position,
		target_position,
		duration
	)
	_transition_tween.tween_property(camera, "zoom", new_target_zoom, duration)
	await _transition_tween.finished

	_transition_tween = null
	_is_transitioning = false
	camera.zoom = new_target_zoom
	camera.global_position = target_position
	if mode == CameraMode.OUTDOOR:
		_outdoor_position_float = target_position
		_apply_outdoor_limits()
		_set_camera_physics_interpolation(true)
	elif mode == CameraMode.INDOOR:
		_apply_fixed_view_limits(target_position, camera.zoom)
		_set_camera_physics_interpolation(false)
	camera.force_update_scroll()
	transition_finished.emit(mode)


func cancel_transition() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	_is_transitioning = false


func is_transitioning() -> bool:
	return _is_transitioning


func current_mode() -> int:
	return mode


## Configured by a scene that supports the lake reveal. Town scenes leave these
## values unused and continue through their existing TITLE/OUTDOOR/INDOOR flow.
func configure_lake_reveal(
	target_x: float,
	normal_zoom_value: float,
	reveal_zoom_value: float,
	normal_right_limit: float,
	reveal_right_limit: float,
	normal_offset_y: float,
	reveal_offset_y: float
) -> void:
	lake_reveal_target_x = target_x
	lake_reveal_normal_zoom = normal_zoom_value
	lake_reveal_zoom = reveal_zoom_value
	lake_reveal_normal_right_limit = normal_right_limit
	lake_reveal_right_limit = reveal_right_limit
	normal_camera_offset_y = normal_offset_y
	lake_reveal_camera_offset_y = reveal_offset_y
	outdoor_right_bound = normal_right_limit
	outdoor_zoom = Vector2.ONE * normal_zoom_value


## Position-driven, reversible reveal. No Tween is created per frame.
func set_lake_reveal_progress(progress: float) -> void:
	_lake_reveal_progress = clampf(progress, 0.0, 1.0)
	if _lake_reveal_progress <= 0.0:
		return

	cancel_transition()
	_lake_reveal_active = true
	mode = CameraMode.LAKE_REVEAL
	camera.top_level = true
	camera.position_smoothing_enabled = false
	_set_camera_physics_interpolation(false)
	_update_lake_reveal_camera()


func exit_lake_reveal() -> void:
	if not _lake_reveal_active:
		return

	_lake_reveal_progress = 0.0
	_lake_reveal_active = false
	mode = CameraMode.OUTDOOR
	camera.zoom = outdoor_zoom
	_apply_outdoor_limits()
	_outdoor_position_float = camera.global_position
	target_position = _calculate_outdoor_target()
	_set_camera_physics_interpolation(true)
	camera.force_update_scroll()


func is_lake_reveal_active() -> bool:
	return _lake_reveal_active


func get_camera() -> Camera2D:
	return camera


func _update_outdoor_camera(delta: float) -> void:
	_apply_outdoor_limits()
	target_position = _calculate_outdoor_target()

	var x_weight := 1.0 - exp(-horizontal_follow_speed * delta)
	var y_speed := vertical_follow_speed if target_position.y < _outdoor_position_float.y else vertical_return_speed
	var y_weight := 1.0 - exp(-y_speed * delta)
	_outdoor_position_float.x = lerpf(_outdoor_position_float.x, target_position.x, x_weight)
	_outdoor_position_float.y = lerpf(_outdoor_position_float.y, target_position.y, y_weight)

	if absf(_outdoor_position_float.x - target_position.x) < 0.05:
		_outdoor_position_float.x = target_position.x
	if absf(_outdoor_position_float.y - target_position.y) < 0.05:
		_outdoor_position_float.y = target_position.y

	camera.global_position = _snap_camera_position(_outdoor_position_float)


func _update_lake_reveal_camera() -> void:
	var eased := smoothstep(0.0, 1.0, _lake_reveal_progress)
	var normal_target := _calculate_outdoor_target()
	normal_target.y = normal_camera_offset_y
	var reveal_target := Vector2(lake_reveal_target_x, lake_reveal_camera_offset_y)
	target_position = _snap_camera_position(normal_target.lerp(reveal_target, eased))
	camera.global_position = target_position
	camera.zoom = Vector2.ONE * lerpf(lake_reveal_normal_zoom, lake_reveal_zoom, eased)
	camera.limit_left = floori(outdoor_left_bound)
	camera.limit_right = ceili(lerpf(
		lake_reveal_normal_right_limit,
		lake_reveal_right_limit,
		eased
	))
	var half_height := _visible_world_half_size(camera.zoom).y
	camera.limit_top = floori(minf(normal_camera_offset_y, lake_reveal_camera_offset_y) - half_height)
	camera.limit_bottom = ceili(maxf(normal_camera_offset_y, lake_reveal_camera_offset_y) + half_height)
	camera.force_update_scroll()


func _calculate_outdoor_target() -> Vector2:
	var half_visible_width := _visible_world_half_size(outdoor_zoom).x
	var min_center_x := outdoor_left_bound + half_visible_width
	var max_center_x := outdoor_right_bound - half_visible_width
	var target_x := (outdoor_left_bound + outdoor_right_bound) * 0.5
	if min_center_x <= max_center_x:
		target_x = clampf(player.global_position.x, min_center_x, max_center_x)

	var ground_camera_y := _ground_camera_y()
	var ground_player_y := outdoor_ground_player_y
	var enter_trigger_y := ground_player_y - vertical_follow_enter_offset
	var exit_trigger_y := ground_player_y - vertical_follow_exit_offset

	if vertical_follow_active:
		if player.global_position.y >= exit_trigger_y:
			vertical_follow_active = false
	elif player.global_position.y < enter_trigger_y:
		vertical_follow_active = true

	var target_y := ground_camera_y
	if vertical_follow_active:
		var height_above_trigger := enter_trigger_y - player.global_position.y
		var effective_height := maxf(height_above_trigger - vertical_dead_zone, 0.0)
		target_y = ground_camera_y - effective_height * vertical_follow_ratio
		target_y = maxf(target_y, _upper_camera_y())
	elif max_ground_vertical_shift > 0.0:
		var ground_difference := ground_player_y - player.global_position.y
		var ground_shift := clampf(
			ground_difference * vertical_follow_ratio,
			-max_ground_vertical_shift,
			max_ground_vertical_shift
		)
		target_y = ground_camera_y - ground_shift

	return Vector2(target_x, target_y)


func _enforce_indoor_lock() -> void:
	target_position = _snap_camera_position(_indoor_camera_position())
	camera.top_level = true
	camera.position_smoothing_enabled = false
	camera.zoom = outdoor_zoom * interior_zoom_multiplier
	_apply_fixed_view_limits(target_position, camera.zoom)
	camera.global_position = target_position


func _save_outdoor_state_if_needed() -> void:
	if mode != CameraMode.OUTDOOR or camera == null:
		return

	saved_outdoor_position = camera.global_position
	saved_outdoor_zoom = camera.zoom
	saved_outdoor_smoothing_enabled = camera.position_smoothing_enabled
	saved_outdoor_smoothing_speed = camera.position_smoothing_speed
	saved_outdoor_limits = Rect2(
		Vector2(camera.limit_left, camera.limit_top),
		Vector2(
			camera.limit_right - camera.limit_left,
			camera.limit_bottom - camera.limit_top
		)
	)
	saved_outdoor_vertical_follow_active = vertical_follow_active


func _refresh_marker_values() -> void:
	if outdoor_ground_camera_marker != null:
		outdoor_ground_camera_y = outdoor_ground_camera_marker.global_position.y
	if outdoor_upper_camera_marker != null:
		outdoor_upper_camera_y = outdoor_upper_camera_marker.global_position.y


func _ground_camera_y() -> float:
	if outdoor_ground_camera_marker != null:
		return outdoor_ground_camera_marker.global_position.y
	return outdoor_ground_camera_y


func _upper_camera_y() -> float:
	if outdoor_upper_camera_marker != null:
		return outdoor_upper_camera_marker.global_position.y
	return outdoor_upper_camera_y


func _indoor_camera_position() -> Vector2:
	if interior_camera_center != null:
		return interior_camera_center.global_position
	return target_position


func _apply_outdoor_limits() -> void:
	camera.limit_left = floori(outdoor_left_bound)
	camera.limit_right = ceili(outdoor_right_bound)
	var half_height := _visible_world_half_size(outdoor_zoom).y
	camera.limit_top = floori(_upper_camera_y() - half_height)
	camera.limit_bottom = ceili(_ground_camera_y() + half_height)


func _apply_fixed_view_limits(center: Vector2, view_zoom: Vector2) -> void:
	var half_size := _visible_world_half_size(view_zoom)
	camera.limit_left = floori(center.x - half_size.x) - 1
	camera.limit_right = ceili(center.x + half_size.x) + 1
	camera.limit_top = floori(center.y - half_size.y) - 1
	camera.limit_bottom = ceili(center.y + half_size.y) + 1


func _apply_transition_limits(
	from_position: Vector2,
	to_position: Vector2,
	from_zoom: Vector2,
	to_zoom: Vector2
) -> void:
	var from_half_size := _visible_world_half_size(from_zoom)
	var to_half_size := _visible_world_half_size(to_zoom)
	camera.limit_left = floori(minf(
		from_position.x - from_half_size.x,
		to_position.x - to_half_size.x
	)) - 1
	camera.limit_right = ceili(maxf(
		from_position.x + from_half_size.x,
		to_position.x + to_half_size.x
	)) + 1
	camera.limit_top = floori(minf(
		from_position.y - from_half_size.y,
		to_position.y - to_half_size.y
	)) - 1
	camera.limit_bottom = ceili(maxf(
		from_position.y + from_half_size.y,
		to_position.y + to_half_size.y
	)) + 1


func _visible_world_half_size(view_zoom: Vector2) -> Vector2:
	var viewport_size := get_viewport_rect().size
	return Vector2(
		viewport_size.x * 0.5 / maxf(view_zoom.x, 0.001),
		viewport_size.y * 0.5 / maxf(view_zoom.y, 0.001)
	)


func _snap_camera_position(value: Vector2) -> Vector2:
	return Vector2(roundf(value.x), roundf(value.y))


func _set_camera_position_from_tween(value: Vector2) -> void:
	camera.global_position = _snap_camera_position(value)


func _set_camera_physics_interpolation(enabled: bool) -> void:
	camera.physics_interpolation_mode = (
		Node.PHYSICS_INTERPOLATION_MODE_ON
		if enabled
		else Node.PHYSICS_INTERPOLATION_MODE_OFF
	)
	camera.reset_physics_interpolation()


func _on_viewport_size_changed() -> void:
	if camera == null:
		return
	if mode == CameraMode.OUTDOOR:
		_apply_outdoor_limits()
	elif mode == CameraMode.INDOOR and not _is_transitioning:
		_apply_fixed_view_limits(_indoor_camera_position(), camera.zoom)
	elif mode == CameraMode.LAKE_REVEAL:
		_update_lake_reveal_camera()


func _update_debug(delta: float) -> void:
	var debug_enabled := debug_camera_bounds and (OS.is_debug_build() or Engine.is_editor_hint())
	if not debug_enabled:
		return

	queue_redraw()
	_debug_print_time += delta
	if _debug_print_time < maxf(debug_print_interval, 0.1):
		return

	_debug_print_time = 0.0
	print(
		"TownCamera mode=", CameraMode.keys()[mode],
		" target=", target_position,
		" actual=", camera.global_position,
		" upper_follow=", vertical_follow_active,
		" bounds=[", outdoor_left_bound, ", ", outdoor_right_bound, "]",
		" ground_y=", _ground_camera_y(),
		" enter_y=", outdoor_ground_player_y - vertical_follow_enter_offset,
		" exit_y=", outdoor_ground_player_y - vertical_follow_exit_offset,
		" upper_y=", _upper_camera_y()
	)


func _draw() -> void:
	if not debug_camera_bounds or not (OS.is_debug_build() or Engine.is_editor_hint()):
		return

	var ground_y := _ground_camera_y()
	var enter_y := outdoor_ground_player_y - vertical_follow_enter_offset
	var exit_y := outdoor_ground_player_y - vertical_follow_exit_offset
	draw_line(Vector2(outdoor_left_bound, -1000.0), Vector2(outdoor_left_bound, 1200.0), Color.RED, 2.0)
	draw_line(Vector2(outdoor_right_bound, -1000.0), Vector2(outdoor_right_bound, 1200.0), Color.RED, 2.0)
	draw_line(Vector2(outdoor_left_bound, ground_y), Vector2(outdoor_right_bound, ground_y), Color.GREEN, 2.0)
	draw_line(Vector2(outdoor_left_bound, enter_y), Vector2(outdoor_right_bound, enter_y), Color.YELLOW, 2.0)
	draw_line(Vector2(outdoor_left_bound, exit_y), Vector2(outdoor_right_bound, exit_y), Color.ORANGE, 2.0)
	draw_line(Vector2(outdoor_left_bound, _upper_camera_y()), Vector2(outdoor_right_bound, _upper_camera_y()), Color.CYAN, 2.0)

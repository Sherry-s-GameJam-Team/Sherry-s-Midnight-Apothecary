@tool
class_name LakeCliffUnderwater
extends DayLevelEnvironment

signal entered_underwater
signal exited_underwater

@export var water_y := 1600.0
@export var elevator_top_y := 900.0
@export var elevator_bottom_y := 4300.0
@export var camera_player_offset := Vector2(0.0, -410.0)
@export var camera_elevator_offset := Vector2(0.0, -540.0)
@export_range(1.0, 20.0, 0.5) var camera_follow_speed := 5.0
@export var debug_draw := false:
	set(value):
		debug_draw = value
		queue_redraw()
@export_node_path("CharacterBody2D") var player_path := NodePath("Player")
@export_node_path("Camera2D") var camera_path := NodePath("CameraSystem/Camera2D")
@export_node_path("AnimatableBody2D") var elevator_path := NodePath("World/ElevatorSystem/Elevator")
@export_node_path("Node") var underwater_controller_path := NodePath("EnvironmentFX/UnderwaterController")
@export_node_path("Node2D") var lakebed_visual_path := NodePath("World/UnderwaterArea/GameplayRuins/LakebedVisual")

var _camera_target: Node2D
var _camera_mode_elevator := false

@onready var player := get_node_or_null(player_path) as CharacterBody2D
@onready var camera := get_node_or_null(camera_path) as Camera2D
@onready var elevator := get_node_or_null(elevator_path) as LakeElevator
@onready var underwater_controller := get_node_or_null(underwater_controller_path) as LakeUnderwaterController


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	super._ready()
	if camera != null:
		camera.add_to_group("lake_transition_camera")
		# This scene owns one smoothing stage. Camera2D's built-in smoothing would
		# otherwise lag behind this controller and make the water crossing drift.
		camera.position_smoothing_enabled = false
		_camera_target = player
	if elevator != null:
		elevator.configure_positions(elevator_top_y, elevator_bottom_y)
		elevator.travel_started.connect(_on_elevator_travel_started)
		elevator.travel_finished.connect(_on_elevator_travel_finished)
	if underwater_controller != null:
		underwater_controller.configure(water_y, elevator_bottom_y)
		underwater_controller.entered_underwater.connect(_on_entered_underwater)
		underwater_controller.exited_underwater.connect(_on_exited_underwater)
	_disable_nested_lakebed_runtime()
	for layer in get_tree().get_nodes_in_group("lake_parallax_layer"):
		if layer.has_method("setup"):
			layer.call("setup", camera)
	_snap_camera_to_target()
	queue_redraw()


func _disable_nested_lakebed_runtime() -> void:
	var lakebed_visual := get_node_or_null(lakebed_visual_path)
	if lakebed_visual == null:
		return
	var nested_background := lakebed_visual.get_node_or_null("Background") as CanvasItem
	if nested_background != null:
		nested_background.visible = false
	var nested_ground := lakebed_visual.get_node_or_null("Ground") as CanvasItem
	if nested_ground != null:
		nested_ground.visible = true
	var nested_player := lakebed_visual.get_node_or_null("Player") as CharacterBody2D
	if nested_player != null:
		nested_player.visible = false
		nested_player.process_mode = Node.PROCESS_MODE_DISABLED
		nested_player.collision_layer = 0
		nested_player.collision_mask = 0
		var nested_camera := nested_player.get_node_or_null("Camera2D") as Camera2D
		if nested_camera != null:
			nested_camera.enabled = false
	var nested_bounds := lakebed_visual.get_node_or_null("WorldBounds")
	if nested_bounds != null:
		nested_bounds.process_mode = Node.PROCESS_MODE_DISABLED
		for collision in nested_bounds.find_children("*", "CollisionShape2D", true, false):
			(collision as CollisionShape2D).disabled = true
	var nested_debug := lakebed_visual.get_node_or_null("DebugUI")
	if nested_debug != null:
		nested_debug.visible = false
		nested_debug.process_mode = Node.PROCESS_MODE_DISABLED


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or camera == null or _camera_target == null:
		return
	var desired := _clamp_camera_center(_camera_target_position())
	var blend := 1.0 - exp(-camera_follow_speed * delta)
	camera.global_position = camera.global_position.lerp(desired, blend)


func is_underwater(global_pos: Vector2) -> bool:
	return global_pos.y > water_y


func _unhandled_key_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_R:
			_reset_elevator_and_player()
		KEY_1:
			_debug_teleport(Vector2(1086.0, elevator_top_y - 90.0), false)
		KEY_2:
			_debug_teleport(Vector2(1086.0, water_y), true)
		KEY_3:
			_debug_teleport(Vector2(1086.0, elevator_bottom_y - 90.0), true)


func _on_elevator_travel_started(_descending: bool) -> void:
	_camera_mode_elevator = true
	_camera_target = elevator
	var elevator_loop := get_node_or_null("Audio/ElevatorLoop") as AudioStreamPlayer
	if elevator_loop != null and elevator_loop.stream != null:
		elevator_loop.play()


func _on_elevator_travel_finished(_at_bottom: bool) -> void:
	_camera_mode_elevator = false
	_camera_target = player
	var elevator_loop := get_node_or_null("Audio/ElevatorLoop") as AudioStreamPlayer
	if elevator_loop != null:
		elevator_loop.stop()
	var stop_sfx := get_node_or_null("Audio/ElevatorStopSFX") as AudioStreamPlayer
	if stop_sfx != null and stop_sfx.stream != null:
		stop_sfx.play()


func _on_entered_underwater() -> void:
	entered_underwater.emit()
	_tween_audio(true)
	var enter_sfx := get_node_or_null("Audio/WaterEnterSFX") as AudioStreamPlayer
	if enter_sfx != null and enter_sfx.stream != null:
		enter_sfx.play()


func _on_exited_underwater() -> void:
	exited_underwater.emit()
	_tween_audio(false)


func _tween_audio(underwater: bool) -> void:
	var above := get_node_or_null("Audio/AudioAboveWater") as AudioStreamPlayer
	var below := get_node_or_null("Audio/AudioUnderwater") as AudioStreamPlayer
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if above != null:
		tween.tween_property(above, "volume_db", -20.0 if underwater else -6.0, 1.2)
	if below != null:
		tween.tween_property(below, "volume_db", 0.0 if underwater else -20.0, 1.2)


func _reset_elevator_and_player() -> void:
	if elevator != null:
		elevator.reset_to_top()
	_debug_teleport(Vector2(1086.0, elevator_top_y - 90.0), false)


func _debug_teleport(target: Vector2, use_elevator_camera: bool) -> void:
	if player != null:
		player.global_position = target
		player.velocity = Vector2.ZERO
	_camera_mode_elevator = use_elevator_camera
	_camera_target = elevator if use_elevator_camera and elevator != null else player
	if elevator != null and use_elevator_camera:
		elevator.global_position.y = target.y + 120.0
	_snap_camera_to_target()
	if underwater_controller != null:
		underwater_controller.force_refresh(true)


func _snap_camera_to_target() -> void:
	if camera == null or _camera_target == null:
		return
	camera.reset_smoothing()
	camera.global_position = _clamp_camera_center(_camera_target_position())


func _camera_target_position() -> Vector2:
	if _camera_target == null:
		return Vector2.ZERO
	return _camera_target.global_position + (camera_elevator_offset if _camera_mode_elevator else camera_player_offset)


func _clamp_camera_center(target: Vector2) -> Vector2:
	if camera == null:
		return target
	var viewport_size := camera.get_viewport_rect().size
	var safe_zoom := Vector2(maxf(camera.zoom.x, 0.001), maxf(camera.zoom.y, 0.001))
	var half_view := viewport_size * 0.5 / safe_zoom
	var min_center := Vector2(camera.limit_left, camera.limit_top) + half_view
	var max_center := Vector2(camera.limit_right, camera.limit_bottom) - half_view
	if min_center.x <= max_center.x:
		target.x = clampf(target.x, min_center.x, max_center.x)
	if min_center.y <= max_center.y:
		target.y = clampf(target.y, min_center.y, max_center.y)
	return target


func _draw() -> void:
	if not debug_draw:
		return
	var width := 2172.0
	draw_line(Vector2(0.0, water_y), Vector2(width, water_y), Color.RED, 4.0)
	draw_line(Vector2(0.0, elevator_top_y), Vector2(width, elevator_top_y), Color.LIME_GREEN, 4.0)
	draw_line(Vector2(0.0, elevator_bottom_y), Vector2(width, elevator_bottom_y), Color.DODGER_BLUE, 4.0)
	draw_rect(Rect2(0.0, water_y + 300.0, width, 700.0), Color(0.1, 0.5, 1.0, 0.12), false, 3.0)
	draw_rect(Rect2(0.0, water_y + 800.0, width, 1200.0), Color(0.2, 1.0, 0.7, 0.12), false, 3.0)
	draw_rect(Rect2(0.0, water_y + 1500.0, width, 1900.0), Color(0.7, 0.2, 1.0, 0.12), false, 3.0)

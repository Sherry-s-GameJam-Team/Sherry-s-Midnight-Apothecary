@tool
class_name LakeCliffUnderwater
extends DayLevelEnvironment

signal entered_underwater
signal exited_underwater

@export var water_y := 1600.0
@export var elevator_top_y := 900.0
@export var elevator_bottom_y := 4300.0
@export var debug_draw := false:
	set(value):
		debug_draw = value
		queue_redraw()
@export_node_path("CharacterBody2D") var player_path := NodePath("Player")
@export_node_path("Camera2D") var camera_path := NodePath("CameraSystem/Camera2D")
@export_node_path("AnimatableBody2D") var elevator_path := NodePath("World/ElevatorSystem/Elevator")
@export_node_path("Node") var underwater_controller_path := NodePath("EnvironmentFX/UnderwaterController")

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
		_camera_target = player
	if elevator != null:
		elevator.configure_positions(elevator_top_y, elevator_bottom_y)
		elevator.travel_started.connect(_on_elevator_travel_started)
		elevator.travel_finished.connect(_on_elevator_travel_finished)
	if underwater_controller != null:
		underwater_controller.configure(water_y, elevator_bottom_y)
		underwater_controller.entered_underwater.connect(_on_entered_underwater)
		underwater_controller.exited_underwater.connect(_on_exited_underwater)
	for layer in get_tree().get_nodes_in_group("lake_parallax_layer"):
		if layer.has_method("setup"):
			layer.call("setup", camera)
	for surface in get_tree().get_nodes_in_group("lake_water_layer"):
		if surface.has_method("setup"):
			surface.call("setup", camera)
	_snap_camera_to_target()
	queue_redraw()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or camera == null or _camera_target == null:
		return
	var desired := _camera_target.global_position
	if _camera_mode_elevator:
		desired += Vector2(0.0, -90.0)
	var blend := 1.0 - exp(-4.0 * delta)
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
			_debug_teleport(Vector2(1086.0, elevator_top_y - 120.0), false)
		KEY_2:
			_debug_teleport(Vector2(1086.0, water_y), true)
		KEY_3:
			_debug_teleport(Vector2(1086.0, elevator_bottom_y - 120.0), true)


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
	_debug_teleport(Vector2(1086.0, elevator_top_y - 120.0), false)


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
	camera.global_position = _camera_target.global_position + (Vector2(0.0, -90.0) if _camera_mode_elevator else Vector2.ZERO)


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

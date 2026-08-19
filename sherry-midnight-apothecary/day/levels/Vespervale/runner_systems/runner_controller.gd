class_name RunnerController
extends Node2D

## Auto-runner controller for the 2-Minute Vespervale Parkour corridor.
## Manages dual-character vertical tracks, independent W/Space jump inputs,
## constant forward camera scrolling, obstacle wave pacing, and finish-line deceleration.

signal runner_started
signal runner_progress_updated(elapsed: float, total: float)
signal runner_finished
signal exit_portal_unlocked

@export var run_speed: float = 300.0
@export var total_duration: float = 120.0 # 2 minutes
@export var lower_track_y: float = 580.0
@export var upper_track_y: float = 320.0
@export var jump_velocity: float = 520.0
@export var gravity: float = 1500.0

var elapsed_time: float = 0.0
var is_running: bool = false
var is_finished: bool = false
var _current_speed: float = 0.0

# Vertical velocities and airborne states for both characters
var _sherry_vel_y: float = 0.0
var _sherry_on_floor: bool = true
var _luca_vel_y: float = 0.0
var _luca_on_floor: bool = true

@export var sherry_path: NodePath = NodePath("../Player")
@export var luca_path: NodePath = NodePath("../Luca")
@export var camera_path: NodePath = NodePath("../Camera2D")
@export var finish_altar_path: NodePath = NodePath("../World/FinishAltar")

@onready var sherry: Node2D = get_node_or_null(sherry_path)
@onready var luca: Node2D = get_node_or_null(luca_path)
@onready var camera: Camera2D = get_node_or_null(camera_path)
@onready var finish_altar: Node2D = get_node_or_null(finish_altar_path)


func _init_nodes() -> void:
	if sherry == null:
		sherry = get_node_or_null(sherry_path)
	if luca == null:
		luca = get_node_or_null(luca_path)
	if camera == null:
		camera = get_node_or_null(camera_path)
	if finish_altar == null:
		finish_altar = get_node_or_null(finish_altar_path)


func _ready() -> void:
	_init_nodes()
	_current_speed = run_speed
	is_running = true
	runner_started.emit()

	# Configure characters for auto-running presentation
	_setup_character_presentation()


func _setup_character_presentation() -> void:
	if sherry != null:
		sherry.position = Vector2(300, lower_track_y)
		# Face right and unbind character default input processing
		sherry.set("depth_scale_enabled", false)
		sherry.set("_facing_right", true)
		sherry.set_physics_process(false)
		sherry.set_process_unhandled_input(false)
	if luca != null:
		luca.position = Vector2(300, upper_track_y)
		if luca.has_method("set_control_enabled"):
			luca.call("set_control_enabled", false)
		luca.set_physics_process(false)
		luca.set_process_unhandled_input(false)

	if camera != null:
		camera.position = Vector2(300 + 240, 420)


func _unhandled_input(event: InputEvent) -> void:
	if is_finished:
		# Check E key to interact with finish altar
		if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.physical_keycode == KEY_E)):
			_trigger_exit()
		return

	if not is_running:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Space key -> Luca (upper track) jumps
		if event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE:
			_try_luca_jump()
			get_viewport().set_input_as_handled()
		# W key -> Sherry (lower track) jumps
		elif event.keycode == KEY_W or event.physical_keycode == KEY_W or event.keycode == KEY_UP or event.physical_keycode == KEY_UP:
			_try_sherry_jump()
			get_viewport().set_input_as_handled()


func _try_sherry_jump() -> void:
	if _sherry_on_floor:
		_sherry_vel_y = -jump_velocity
		_sherry_on_floor = false
		if sherry != null and sherry.has_method("_play"):
			sherry.call("_play", "jump_takeoff")


func _try_luca_jump() -> void:
	if _luca_on_floor:
		_luca_vel_y = -jump_velocity
		_luca_on_floor = false
		if luca != null and luca.has_method("_play_jump"):
			luca.call("_play_jump")


func _physics_process(delta: float) -> void:
	if not is_running:
		return

	if not is_finished:
		elapsed_time += delta
		runner_progress_updated.emit(elapsed_time, total_duration)

		if elapsed_time >= total_duration:
			_start_finish_sequence()

	# Move forward horizontally
	var move_x := _current_speed * delta
	if sherry != null:
		sherry.position.x += move_x
	if luca != null:
		luca.position.x += move_x
	if camera != null and not is_finished:
		camera.position.x += move_x

	# Update vertical physics for Sherry
	if not _sherry_on_floor or _sherry_vel_y != 0.0:
		_sherry_vel_y += gravity * delta
		if sherry != null:
			sherry.position.y += _sherry_vel_y * delta
			if sherry.position.y >= lower_track_y:
				sherry.position.y = lower_track_y
				_sherry_vel_y = 0.0
				_sherry_on_floor = true
				if not is_finished and sherry.has_method("_play"):
					sherry.call("_play", "run")

	# Update vertical physics for Luca
	if not _luca_on_floor or _luca_vel_y != 0.0:
		_luca_vel_y += gravity * delta
		if luca != null:
			luca.position.y += _luca_vel_y * delta
			if luca.position.y >= upper_track_y:
				luca.position.y = upper_track_y
				_luca_vel_y = 0.0
				_luca_on_floor = true
				if not is_finished and luca.has_method("_play_run_loop"):
					luca.call("_play_run_loop")

	# Maintain running animations while grounded and moving
	if not is_finished and _current_speed > 20.0:
		if _sherry_on_floor and sherry != null and sherry.has_method("_play"):
			sherry.call("_play", "run")
		if _luca_on_floor and luca != null and luca.has_method("_play_run_loop"):
			luca.call("_play_run_loop")


func _start_finish_sequence() -> void:
	is_finished = true
	runner_finished.emit()

	# Decelerate speed smoothly to zero
	var tw := create_tween()
	tw.tween_property(self, "_current_speed", 0.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_on_stopped_at_finish)


func _on_stopped_at_finish() -> void:
	_current_speed = 0.0

	# Transition characters to idle
	if sherry != null and sherry.has_method("_play"):
		sherry.call("_play", "idle")
	if luca != null and luca.has_method("_play_idle"):
		luca.call("_play_idle")

	exit_portal_unlocked.emit()

	# Show finish prompt
	var top_hint := _find_top_hint()
	if top_hint != null and top_hint.has_method("show_interaction_hint"):
		top_hint.call("show_interaction_hint", "RunnerFinish", "抵达终点！按 E 离开梦境疾驰")


func _trigger_exit() -> void:
	var env := _find_environment()
	if env != null:
		if env.has_method("on_runner_completed"):
			env.call("on_runner_completed")
		elif env.has_signal("level_completed"):
			env.emit_signal("level_completed")


func _find_top_hint() -> Node:
	var cur: Node = self
	while cur != null:
		var hint := cur.get_node_or_null("PauseMenuLayer/TopHintUI")
		if hint == null:
			hint = cur.get_node_or_null("TopHintUI")
		if hint != null:
			return hint
		cur = cur.get_parent()
	return null


func _find_environment() -> Node:
	var cur: Node = self
	while cur != null:
		if cur is DayLevelEnvironment:
			return cur
		cur = cur.get_parent()
	return null

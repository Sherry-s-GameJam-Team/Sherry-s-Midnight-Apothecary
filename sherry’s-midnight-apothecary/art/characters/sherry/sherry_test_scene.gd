extends Control

const STAGE_LEFT := 120.0
const STAGE_RIGHT := 1160.0
const WALK_JUMP_VELOCITY := -405.0
const RUN_JUMP_VELOCITY := -450.0
const WALK_JUMP_GRAVITY := 925.0
const RUN_JUMP_GRAVITY := 850.0
const AIR_CONTROL_ACCELERATION := 700.0
const AIR_DRAG := 90.0
const DOUBLE_TAP_WINDOW_MS := 260
const ROLL_SPEED_MULTIPLIER := 1.8

@export_group("Character Tuning")
@export_range(0.3, 1.2, 0.01) var character_scale := 0.4:
	set(value):
		character_scale = value
		if is_instance_valid(sprite):
			sprite.scale = Vector2.ONE * character_scale
@export_range(50.0, 500.0, 5.0) var walk_speed := 50.0
@export_range(50.0, 700.0, 5.0) var run_speed := 200.0

@onready var sprite: Node2D = %SherrySprite
@onready var visual: Sprite2D = %SherryVisual
@onready var animation_player: AnimationPlayer = %SherryAnimationPlayer
@onready var state_label: Label = %StateLabel
@onready var scale_spin: SpinBox = %ScaleSpin
@onready var walk_speed_spin: SpinBox = %WalkSpeedSpin
@onready var run_speed_spin: SpinBox = %RunSpeedSpin

var _state := "idle"
var _transition_target := "idle"
var _ground_y := 515.0
var _vertical_velocity := 0.0
var _horizontal_velocity := 0.0
var _jump_speed_ratio := 0.0
var _is_airborne := false
var _facing_right := false
var _is_rolling := false
var _roll_direction := 0.0
var _last_a_tap_ms := -10000
var _last_d_tap_ms := -10000


func _ready() -> void:
	animation_player.animation_finished.connect(_on_animation_finished)
	_ground_y = sprite.position.y
	sprite.scale = Vector2.ONE * character_scale
	_sync_debug_panel()
	_play("idle")


func _process(delta: float) -> void:
	var direction := _get_input_direction()
	_update_jump(delta, direction)
	if not is_zero_approx(direction) and _facing_right != (direction > 0.0):
		_facing_right = direction > 0.0
		if not _is_transition():
			_play(_state)
	if not _is_airborne and _state == "land" and not is_zero_approx(direction):
		_transition_target = _ground_action_for(direction)
		_play(_transition_target)
	if _is_rolling:
		sprite.position.x = clampf(sprite.position.x + _roll_direction * run_speed * ROLL_SPEED_MULTIPLIER * delta, STAGE_LEFT, STAGE_RIGHT)
	if not _is_airborne and _state in ["walk", "run"]:
		var speed := _current_move_speed()
		sprite.position.x = clampf(sprite.position.x + direction * speed * delta, STAGE_LEFT, STAGE_RIGHT)
	if not _is_transition() and not _is_airborne:
		_update_locomotion(direction)
	_update_status(direction)


func _update_locomotion(direction: float) -> void:
	if is_zero_approx(direction):
		if _state != "idle":
			_play("idle")
		return
	var wants_run := _is_running()
	if _state == "idle":
		_play("run" if wants_run else "walk")
	elif _state == "walk" and wants_run:
		_play("run")
	elif _state == "run" and not wants_run:
		_play("walk")


func _play(action: String) -> void:
	var animation_name := "%s_right" % action if _facing_right else action
	if _state == action and animation_player.current_animation == animation_name and animation_player.is_playing():
		return
	_state = action
	_apply_action_scale()
	animation_player.play(animation_name)


func _is_transition() -> bool:
	var animation := animation_player.get_animation(_state)
	return animation == null or animation.loop_mode == Animation.LOOP_NONE


func _on_animation_finished(_animation_name: StringName) -> void:
	if _state == "roll":
		_is_rolling = false
		_play(_ground_action_for(_get_input_direction()))
	elif _state == "prejump":
		_play("jump_takeoff")
	elif _state == "jump_takeoff":
		_play("jump_fall")
	elif _state == "land":
		_play(_ground_action_for(_get_input_direction()))
	elif _is_transition():
		_play(_transition_target)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo or _is_transition():
		return
	match key_event.keycode:
		KEY_A, KEY_D:
			_try_start_roll(key_event.keycode)
		KEY_SPACE:
			_play_one_shot("throw")
		KEY_H:
			_play_one_shot("hit")
		KEY_F:
			_play_one_shot("cast")
		KEY_W:
			_start_jump()


func _play_one_shot(action: String) -> void:
	_transition_target = "idle"
	_play(action)


func _start_jump() -> void:
	if _is_airborne or _is_rolling:
		return
	var takeoff_speed := absf(_get_input_direction()) * _current_move_speed()
	_jump_speed_ratio = clampf(takeoff_speed / run_speed, 0.0, 1.0)
	_is_airborne = true
	_vertical_velocity = lerpf(WALK_JUMP_VELOCITY, RUN_JUMP_VELOCITY, _jump_speed_ratio)
	_horizontal_velocity = _get_input_direction() * takeoff_speed
	_play("prejump")


func _try_start_roll(keycode: int) -> void:
	if _is_airborne or _is_rolling:
		return
	var now := Time.get_ticks_msec()
	var previous_tap := _last_a_tap_ms if keycode == KEY_A else _last_d_tap_ms
	if now - previous_tap > DOUBLE_TAP_WINDOW_MS:
		if keycode == KEY_A:
			_last_a_tap_ms = now
		else:
			_last_d_tap_ms = now
		return
	_last_a_tap_ms = -10000
	_last_d_tap_ms = -10000
	_roll_direction = -1.0 if keycode == KEY_A else 1.0
	_facing_right = _roll_direction > 0.0
	_is_rolling = true
	_play("roll")


func _update_jump(delta: float, direction: float) -> void:
	if not _is_airborne:
		return
	var air_speed := _current_move_speed()
	if not is_zero_approx(direction):
		_horizontal_velocity = move_toward(_horizontal_velocity, direction * air_speed, AIR_CONTROL_ACCELERATION * delta)
	else:
		_horizontal_velocity = move_toward(_horizontal_velocity, 0.0, AIR_DRAG * delta)
	sprite.position.y += _vertical_velocity * delta
	sprite.position.x = clampf(sprite.position.x + _horizontal_velocity * delta, STAGE_LEFT, STAGE_RIGHT)
	_vertical_velocity += lerpf(WALK_JUMP_GRAVITY, RUN_JUMP_GRAVITY, _jump_speed_ratio) * delta
	if sprite.position.y >= _ground_y:
		sprite.position.y = _ground_y
		_vertical_velocity = 0.0
		_horizontal_velocity = 0.0
		_jump_speed_ratio = 0.0
		_is_airborne = false
		_transition_target = _ground_action_for(direction)
		_play("land")


func _apply_action_scale() -> void:
	sprite.scale = Vector2.ONE * character_scale


func _get_input_direction() -> float:
	var left := 1.0 if Input.is_key_pressed(KEY_A) else 0.0
	var right := 1.0 if Input.is_key_pressed(KEY_D) else 0.0
	return right - left


func _is_running() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)


func _current_move_speed() -> float:
	return run_speed if _is_running() else walk_speed


func _ground_action_for(direction: float) -> String:
	if is_zero_approx(direction):
		return "idle"
	return "run" if _is_running() else "walk"


func _sync_debug_panel() -> void:
	scale_spin.value = character_scale
	walk_speed_spin.value = walk_speed
	run_speed_spin.value = run_speed


func _on_scale_spin_value_changed(value: float) -> void:
	character_scale = value
	_apply_action_scale()


func _on_walk_speed_spin_value_changed(value: float) -> void:
	walk_speed = value


func _on_run_speed_spin_value_changed(value: float) -> void:
	run_speed = value


func _on_reset_tuning_pressed() -> void:
	character_scale = 0.4
	walk_speed = 50.0
	run_speed = 200.0
	_apply_action_scale()
	_sync_debug_panel()


func _update_status(direction: float) -> void:
	var direction_text := "静止"
	if direction < 0.0:
		direction_text = "向左"
	elif direction > 0.0:
		direction_text = "向右"
	state_label.text = "当前动作：%s  ·  %s" % [_state, direction_text]

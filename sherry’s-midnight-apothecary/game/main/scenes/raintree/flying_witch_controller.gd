extends CharacterBody2D

const MODE_GROUND := 0
const MODE_FLIGHT := 1
const TOWN_FRAMES = preload("res://game/src/sprite/lost_ruins_witch/lost_ruins_witch_sprite_frames.tres")
const FLIGHT_FRAMES = preload("res://game/src/sprite/witch/witch_sprite_frames.tres")
const ANIMATION_IDLE := &"idle"
const ANIMATION_RUN := &"run"
const ANIMATION_JUMP := &"jump"
const ANIMATION_FALLING := &"falling"
const ANIMATION_LANDING := &"landing"
const ANIMATION_ATTACK := &"attack_one_handed_aerial"
const FLIGHT_ANIMATION_IDLE := &"stand"
const FLIGHT_ANIMATION_ATTACK := &"attack"
const TOWN_SPRITE_POSITION := Vector2(0, -43)
const TOWN_COLLISION_POSITION := Vector2(0, -48)
const TOWN_COLLISION_SIZE := Vector2(48, 96)
const FLIGHT_SPRITE_POSITION := Vector2(0, -30)
const FLIGHT_COLLISION_POSITION := Vector2(0, -30)
const FLIGHT_COLLISION_SIZE := Vector2(62, 46)

@export var walk_speed := 260.0
@export var run_speed := 430.0
@export var jump_velocity := -720.0
@export var max_air_jumps := 1
@export var gravity := 1900.0
@export var fly_speed := 320.0
@export var boost_speed := 520.0
@export var acceleration := 1800.0
@export var friction := 2200.0
@export var min_x := -2110.0
@export var max_x := 4280.0
@export var min_y := -2250.0
@export var max_y := 648.0

@onready var sprite_pivot: Node2D = $SpritePivot
@onready var character_sprite: AnimatedSprite2D = $SpritePivot/WitchSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var player_camera: Camera2D = $Camera2D
@onready var double_jump_particles: CPUParticles2D = $DoubleJumpParticles

var control_mode := MODE_GROUND
var input_locked := false
var is_attacking := false
var air_jumps_used := 0


func _ready() -> void:
	character_sprite.animation_finished.connect(_on_character_sprite_animation_finished)
	_apply_control_mode()
	character_sprite.play(_idle_animation())
	player_camera.position = player_camera.position.round()


func _input(event: InputEvent) -> void:
	if input_locked:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_R:
				_toggle_control_mode()
			elif control_mode == MODE_GROUND and key_event.keycode == KEY_W:
				_request_ground_jump()
			elif key_event.keycode == KEY_J:
				_start_attack()
	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_start_attack()


func _physics_process(delta: float) -> void:
	if input_locked:
		velocity = Vector2.ZERO
		_apply_world_bounds()
		if not is_attacking:
			_play_animation(_idle_animation())
		return

	if control_mode == MODE_FLIGHT:
		_update_flight(delta)
	else:
		_update_ground(delta)

	_apply_world_bounds()


func set_input_locked(locked: bool) -> void:
	input_locked = locked
	if input_locked:
		velocity = Vector2.ZERO
		is_attacking = false
		_play_animation(_idle_animation())


func _toggle_control_mode() -> void:
	control_mode = MODE_FLIGHT if control_mode == MODE_GROUND else MODE_GROUND
	velocity = Vector2.ZERO
	is_attacking = false
	air_jumps_used = 0
	_apply_control_mode()
	_play_animation(_idle_animation())


func _apply_control_mode() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING if control_mode == MODE_FLIGHT else CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 0.0 if control_mode == MODE_FLIGHT else 8.0
	character_sprite.sprite_frames = FLIGHT_FRAMES if control_mode == MODE_FLIGHT else TOWN_FRAMES
	character_sprite.position = FLIGHT_SPRITE_POSITION if control_mode == MODE_FLIGHT else TOWN_SPRITE_POSITION
	collision_shape.position = FLIGHT_COLLISION_POSITION if control_mode == MODE_FLIGHT else TOWN_COLLISION_POSITION

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle != null:
		rectangle.size = FLIGHT_COLLISION_SIZE if control_mode == MODE_FLIGHT else TOWN_COLLISION_SIZE


func _update_flight(delta: float) -> void:
	var input_vector := _flight_vector()
	var target_velocity := input_vector * _movement_speed()
	var velocity_change := acceleration if not input_vector.is_zero_approx() else friction

	velocity = velocity.move_toward(target_velocity, velocity_change * delta)
	move_and_slide()

	if not is_zero_approx(input_vector.x):
		_face_direction(input_vector.x)
	if not is_attacking:
		_play_animation(_idle_animation())


func _update_ground(delta: float) -> void:
	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0
	if not is_on_floor():
		velocity.y += gravity * delta

	var input_direction := _horizontal_direction()
	var target_velocity_x := input_direction * _movement_speed()
	var velocity_change := acceleration if not is_zero_approx(input_direction) else friction
	velocity.x = move_toward(velocity.x, target_velocity_x, velocity_change * delta)

	var was_grounded := is_on_floor()
	move_and_slide()

	if is_on_floor():
		air_jumps_used = 0

	if not is_zero_approx(input_direction):
		_face_direction(input_direction)

	if is_attacking:
		return
	if not was_grounded and is_on_floor():
		_play_animation(ANIMATION_LANDING)
	elif not is_on_floor():
		_play_animation(ANIMATION_FALLING)
	elif not is_zero_approx(input_direction):
		_play_animation(ANIMATION_RUN)
	else:
		_play_animation(ANIMATION_IDLE)


func _flight_vector() -> Vector2:
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0

	return direction.normalized() if direction.length_squared() > 1.0 else direction


func _horizontal_direction() -> float:
	var direction := 0.0
	if Input.is_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction += 1.0
	return clampf(direction, -1.0, 1.0)


func _movement_speed() -> float:
	if control_mode == MODE_FLIGHT:
		return boost_speed if Input.is_key_pressed(KEY_SHIFT) else fly_speed
	return run_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed


func _request_ground_jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity
		_play_animation(ANIMATION_JUMP)
	elif air_jumps_used < max_air_jumps:
		air_jumps_used += 1
		velocity.y = jump_velocity
		_play_double_jump_effect()
		_play_animation(ANIMATION_JUMP)


func _play_double_jump_effect() -> void:
	double_jump_particles.restart()
	double_jump_particles.emitting = true


func _start_attack() -> void:
	if is_attacking:
		return

	is_attacking = true
	_play_animation(_attack_animation())


func _play_animation(animation_name: StringName) -> void:
	if character_sprite.animation != animation_name:
		character_sprite.play(animation_name)
	elif not character_sprite.is_playing():
		character_sprite.play(animation_name)


func _idle_animation() -> StringName:
	return FLIGHT_ANIMATION_IDLE if control_mode == MODE_FLIGHT else ANIMATION_IDLE


func _attack_animation() -> StringName:
	return FLIGHT_ANIMATION_ATTACK if control_mode == MODE_FLIGHT else ANIMATION_ATTACK


func _face_direction(direction: float) -> void:
	var facing_scale := absf(sprite_pivot.scale.x)
	sprite_pivot.scale.x = -facing_scale if direction < 0.0 else facing_scale


func _on_character_sprite_animation_finished() -> void:
	if character_sprite.animation == _attack_animation():
		is_attacking = false
	if character_sprite.animation == ANIMATION_LANDING:
		_play_animation(_idle_animation())


func _apply_world_bounds() -> void:
	var clamped_position := Vector2(
		clampf(global_position.x, min_x, max_x),
		clampf(global_position.y, min_y, max_y)
	)

	if not is_equal_approx(global_position.x, clamped_position.x):
		velocity.x = 0.0
	if not is_equal_approx(global_position.y, clamped_position.y):
		velocity.y = 0.0

	global_position = clamped_position.round()

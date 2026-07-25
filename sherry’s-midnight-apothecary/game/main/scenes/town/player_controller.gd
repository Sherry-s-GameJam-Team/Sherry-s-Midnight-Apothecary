extends CharacterBody2D

const ANIMATION_IDLE := &"idle"
const ANIMATION_IDLE_TO_RUN := &"idle_to_run"
const ANIMATION_RUN := &"run"
const ANIMATION_RUN_TO_IDLE := &"run_to_idle"
const ANIMATION_CROUCH := &"crouch"
const ANIMATION_CROUCHING := &"crouching"
const ANIMATION_CROUCH_TO_IDLE := &"crouch_to_idle"
const ANIMATION_ROLL := &"roll"
const ANIMATION_JUMP := &"jump"
const ANIMATION_FALLING := &"falling"
const ANIMATION_LANDING := &"landing"
const ANIMATION_BLOCKING := &"blocking_with_shield"
const ANIMATION_HIT_WHEN_BLOCKING := &"hit_when_blocking"
const ANIMATION_DAMAGE_TAKEN := &"damage_taken"
const ANIMATION_DEAD := &"dead"
const DROP_THROUGH_PLATFORM_GROUP := &"drop_through_platform"
const DROP_THROUGH_DURATION := 0.18
const DROP_THROUGH_FALL_SPEED := 90.0
const DEFAULT_FLOOR_SNAP_LENGTH := 8.0
const WATER_BOTTLE_PROJECTILE_SCENE := preload("res://game/src/projectiles/water_bottle_projectile.tscn")

@export var walk_speed := 260.0
@export var run_speed := 430.0
@export var jump_velocity := -720.0
@export var jump_buffer_time := 0.12
@export var max_air_jumps := 1
@export var gravity := 1900.0
@export var acceleration := 1800.0
@export var friction := 2200.0
@export var min_x := 64.0
@export var max_x := 5864.0
@export var min_y := 220.0
@export var max_y := 680.0
@export var throw_cooldown := 0.45

@onready var sprite_pivot: Node2D = $SpritePivot
@onready var character_sprite: AnimatedSprite2D = $SpritePivot/WitchSprite
@onready var double_jump_particles: CPUParticles2D = $DoubleJumpParticles
@onready var water_throw_point: Marker2D = $WaterThrowPoint

var action_locked := false
var queued_animation := &""
var is_crouching := false
var is_aerial := false
var is_dead := false
var input_locked := false
var was_moving := false
var jump_buffer_timer := 0.0
var air_jumps_used := 0
var drop_through_body: PhysicsBody2D = null
var drop_through_collision: CollisionShape2D = null
var drop_through_collision_was_disabled := false
var drop_through_restore_when_falling := false
var drop_through_timer := 0.0
var water_throw_timer := 0.0


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	reset_physics_interpolation()
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = DEFAULT_FLOOR_SNAP_LENGTH
	character_sprite.animation_finished.connect(_on_character_sprite_animation_finished)
	character_sprite.play(ANIMATION_IDLE)
	_update_water_throw_point()


func _input(event: InputEvent) -> void:
	if input_locked:
		return

	if event.is_action_pressed(&"throw_water") and _try_throw_water():
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed:
			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				_start_context_action("attack_dagger")
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				_start_context_action("attack_bow")
	elif event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_W:
				_request_jump()
			else:
				_handle_key_action(key_event.keycode)


func _physics_process(delta: float) -> void:
	_update_drop_through(delta)
	water_throw_timer = maxf(water_throw_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	var was_grounded := is_on_floor()
	_apply_gravity(delta)

	var input_direction := _horizontal_direction()
	if input_locked or is_dead or _is_crouch_pressed() or Input.is_key_pressed(KEY_F):
		input_direction = 0.0

	var target_velocity_x := input_direction * _movement_speed()
	var velocity_change := acceleration if not is_zero_approx(input_direction) else friction

	velocity.x = move_toward(velocity.x, target_velocity_x, velocity_change * delta)

	move_and_slide()
	_apply_world_bounds()

	if not is_zero_approx(input_direction):
		var facing_scale := absf(sprite_pivot.scale.x)
		sprite_pivot.scale.x = -facing_scale if input_direction < 0.0 else facing_scale
		_update_water_throw_point()

	if is_on_floor():
		air_jumps_used = 0

	is_aerial = not is_on_floor()
	if _consume_jump_buffer():
		return

	if not was_grounded and is_on_floor():
		_start_action(ANIMATION_LANDING)
	else:
		_update_animation_from_inputs(input_direction)


func _horizontal_direction() -> float:
	if input_locked:
		return 0.0

	var direction := 0.0

	if Input.is_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction += 1.0

	return clampf(direction, -1.0, 1.0)


func _movement_speed() -> float:
	if input_locked:
		return walk_speed

	return run_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed


func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0
	if not is_on_floor():
		velocity.y += gravity * delta


func _handle_key_action(keycode: Key) -> void:
	if is_dead or action_locked:
		return

	match keycode:
		KEY_Q:
			_try_throw_water()
		KEY_J:
			_start_context_action("attack_one_handed")
		KEY_K:
			_start_context_action("attack_two_handed")
		KEY_M:
			_start_context_action("attack_missile_launcher")
		KEY_1:
			_start_context_action("casting_spell_1")
		KEY_2:
			_start_context_action("casting_spell_2")
		KEY_3:
			_start_context_action("casting_spell_3")
		KEY_F:
			if Input.is_key_pressed(KEY_SHIFT):
				_start_action(_blocked_hit_animation())
		KEY_X:
			_start_action(ANIMATION_DAMAGE_TAKEN)
		KEY_P:
			is_dead = true
			velocity = Vector2.ZERO
			_start_action(ANIMATION_DEAD)


func _try_throw_water() -> bool:
	if is_dead or water_throw_timer > 0.0:
		return false

	water_throw_timer = throw_cooldown
	var projectile: Node2D = WATER_BOTTLE_PROJECTILE_SCENE.instantiate() as Node2D
	projectile.global_position = water_throw_point.global_position
	get_tree().current_scene.add_child(projectile)

	var direction_x: float = signf(sprite_pivot.scale.x)
	if is_zero_approx(direction_x):
		direction_x = 1.0
	projectile.call("launch", Vector2(direction_x, -0.16).normalized(), self)
	return true


func _update_water_throw_point() -> void:
	var facing_x: float = 1.0 if sprite_pivot.scale.x >= 0.0 else -1.0
	water_throw_point.position.x = absf(water_throw_point.position.x) * facing_x


func _request_jump() -> void:
	if input_locked or is_dead:
		return

	if _is_drop_through_requested() and _try_drop_through_platform():
		return

	jump_buffer_timer = jump_buffer_time
	_consume_jump_buffer()


func _consume_jump_buffer() -> bool:
	if jump_buffer_timer <= 0.0 or not _can_start_jump():
		return false

	jump_buffer_timer = 0.0
	_start_jump()
	return true


func _can_start_jump() -> bool:
	if input_locked:
		return false

	if _is_crouch_pressed():
		return false

	if not is_on_floor():
		return air_jumps_used < max_air_jumps and _can_interrupt_for_air_jump()

	if not action_locked:
		return true

	return character_sprite.animation in [
		ANIMATION_LANDING,
		ANIMATION_IDLE_TO_RUN,
		ANIMATION_RUN_TO_IDLE,
		ANIMATION_CROUCH_TO_IDLE,
	]


func _can_interrupt_for_air_jump() -> bool:
	if not action_locked:
		return true

	return character_sprite.animation in [
		ANIMATION_JUMP,
		ANIMATION_FALLING,
	]


func _start_jump() -> void:
	var is_air_jump := not is_on_floor()
	if is_air_jump:
		air_jumps_used += 1
		_play_double_jump_effect()
	else:
		_hide_current_platform_collision_until_falling()

	queued_animation = &""
	is_crouching = false
	velocity.y = jump_velocity
	is_aerial = true
	_start_action(ANIMATION_JUMP)


func _play_double_jump_effect() -> void:
	double_jump_particles.restart()
	double_jump_particles.emitting = true


func _is_drop_through_requested() -> bool:
	return is_on_floor() and _is_crouch_pressed()


func _try_drop_through_platform() -> bool:
	var platform := _current_drop_through_platform()
	if platform == null:
		return false

	_hide_platform_collision(platform, false)
	floor_snap_length = 0.0
	velocity.y = maxf(velocity.y, DROP_THROUGH_FALL_SPEED)
	jump_buffer_timer = 0.0
	is_aerial = true
	action_locked = false
	_play_animation(ANIMATION_FALLING)
	return true


func _hide_current_platform_collision_until_falling() -> void:
	var platform := _current_drop_through_platform()
	if platform == null:
		return

	_hide_platform_collision(platform, true)


func _hide_platform_collision(platform: PhysicsBody2D, restore_when_falling: bool) -> void:
	if drop_through_body != null:
		_clear_drop_through_platform()

	var platform_collision := platform.get_node_or_null("Floor") as CollisionShape2D
	drop_through_body = platform
	drop_through_collision = platform_collision
	drop_through_restore_when_falling = restore_when_falling
	drop_through_timer = DROP_THROUGH_DURATION
	if drop_through_collision != null:
		drop_through_collision_was_disabled = drop_through_collision.disabled
		drop_through_collision.disabled = true
	else:
		add_collision_exception_with(drop_through_body)


func _current_drop_through_platform() -> PhysicsBody2D:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		if collision == null or collision.get_normal().y > -0.5:
			continue

		var collider := collision.get_collider() as PhysicsBody2D
		if collider != null and collider.is_in_group(DROP_THROUGH_PLATFORM_GROUP):
			return collider

	return null


func _update_drop_through(delta: float) -> void:
	if drop_through_body == null:
		return

	drop_through_timer = maxf(drop_through_timer - delta, 0.0)
	if drop_through_restore_when_falling and velocity.y < 0.0:
		return
	if drop_through_timer > 0.0:
		return

	_clear_drop_through_platform()


func _clear_drop_through_platform() -> void:
	if is_instance_valid(drop_through_collision):
		drop_through_collision.disabled = drop_through_collision_was_disabled
	elif is_instance_valid(drop_through_body):
		remove_collision_exception_with(drop_through_body)
	drop_through_body = null
	drop_through_collision = null
	drop_through_collision_was_disabled = false
	drop_through_restore_when_falling = false
	floor_snap_length = DEFAULT_FLOOR_SNAP_LENGTH


func _update_animation_from_inputs(input_direction: float) -> void:
	if is_dead:
		return

	if action_locked:
		return

	if not is_on_floor():
		is_aerial = true
		_play_animation(ANIMATION_FALLING)
		return

	if Input.is_key_pressed(KEY_F):
		was_moving = false
		_play_animation(ANIMATION_BLOCKING)
		return

	if _is_crouch_pressed():
		was_moving = false
		if not is_crouching:
			is_crouching = true
			_start_action(ANIMATION_CROUCH)
		else:
			_play_animation(ANIMATION_CROUCHING)
		return

	if is_crouching:
		is_crouching = false
		_start_action(ANIMATION_CROUCH_TO_IDLE)
		return

	var is_moving := not is_zero_approx(input_direction)
	if is_moving:
		if not was_moving:
			was_moving = true
			_start_action(ANIMATION_IDLE_TO_RUN, ANIMATION_RUN)
		else:
			_play_animation(ANIMATION_RUN)
	else:
		if was_moving:
			was_moving = false
			_start_action(ANIMATION_RUN_TO_IDLE, ANIMATION_IDLE)
		else:
			_play_animation(ANIMATION_IDLE)


func _start_context_action(action_prefix: String) -> void:
	if is_dead or action_locked:
		return

	_start_action(StringName("%s_%s" % [action_prefix, _stance_suffix()]))


func _stance_suffix() -> String:
	if is_aerial or not is_on_floor():
		return "aerial"
	if is_on_floor() and (is_crouching or _is_crouch_pressed()):
		return "crouching"
	return "standing"


func _blocked_hit_animation() -> StringName:
	if is_crouching or _is_crouch_pressed():
		return &"attack_blocked_crouching"
	return &"attack_blocked_standing_aerial"


func _is_crouch_pressed() -> bool:
	if input_locked:
		return false

	return Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL)


func set_input_locked(locked: bool) -> void:
	input_locked = locked
	if input_locked:
		_clear_drop_through_platform()
		jump_buffer_timer = 0.0
		velocity.x = 0.0
		was_moving = false
		if not is_dead and not action_locked and is_on_floor():
			_play_animation(ANIMATION_IDLE)


func _start_action(animation_name: StringName, next_animation: StringName = &"") -> void:
	action_locked = true
	queued_animation = next_animation
	_play_animation(animation_name)


func _play_animation(animation_name: StringName) -> void:
	if character_sprite.animation != animation_name:
		character_sprite.play(animation_name)
	elif not character_sprite.is_playing():
		character_sprite.play(animation_name)


func _on_character_sprite_animation_finished() -> void:
	var finished_animation := character_sprite.animation
	if finished_animation == ANIMATION_DEAD:
		return

	if finished_animation == ANIMATION_JUMP:
		action_locked = false
		if is_on_floor():
			is_aerial = false
			_start_action(ANIMATION_LANDING)
		else:
			is_aerial = true
			_play_animation(ANIMATION_FALLING)
		return

	if finished_animation == ANIMATION_CROUCH:
		action_locked = false
		_play_animation(ANIMATION_CROUCHING)
		return

	if queued_animation != &"":
		var next_animation := queued_animation
		queued_animation = &""
		action_locked = false
		_play_animation(next_animation)
		return

	action_locked = false
	_update_animation_from_inputs(_horizontal_direction())


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

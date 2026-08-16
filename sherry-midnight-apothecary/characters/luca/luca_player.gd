class_name LucaPlayer
extends CharacterBody2D

signal movement_started
signal movement_stopped
signal jumped
signal landed

enum LocomotionState {
	IDLE,
	RUN_START,
	RUN_LOOP,
	JUMP,
	FALL,
}

const IDLE_ANIMATION := &"idle"
const RUN_START_ANIMATION := &"run_start"
const RUN_LOOP_ANIMATION := &"run_loop"
const JUMP_ANIMATION := &"jump"
const FALL_ANIMATION := &"fall"

## Collision layer 2 is reserved for one-way platforms that players can drop through.
const DROP_THROUGH_PLATFORM_LAYER := 1 << 1
const DROP_THROUGH_DURATION := 0.18
const DROP_THROUGH_START_SPEED := 80.0

@export_group("Movement")
@export_range(10.0, 1000.0, 5.0, "suffix:px/s") var move_speed := 280.0
@export_range(0.0, 4000.0, 10.0, "suffix:px/s²") var gravity := 1400.0
@export_range(0.0, 4000.0, 10.0, "suffix:px/s") var max_fall_speed := 900.0
@export_range(50.0, 1500.0, 10.0, "suffix:px/s") var jump_velocity := 550.0
@export_range(1.0, 5.0, 0.1) var jump_cut_gravity_multiplier := 2.8
@export_range(0.0, 0.5, 0.01, "suffix:s") var coyote_time := 0.12
@export_range(0.0, 0.5, 0.01, "suffix:s") var jump_buffer_time := 0.12
@export var input_enabled := true

@export_group("Presentation")
## Luca's source art faces left. Enable this only if the source frames are replaced
## with right-facing art.
@export var source_faces_right := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var locomotion_state := LocomotionState.IDLE
var _movement_direction := 0.0
var _external_direction := 0.0
var _is_airborne := false
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _drop_through_timer := 0.0
var _default_floor_snap_length := 0.0


func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_default_floor_snap_length = floor_snap_length
	collision_mask |= DROP_THROUGH_PLATFORM_LAYER
	_sync_camera_process_mode()
	_play_idle()


func _sync_camera_process_mode() -> void:
	for child: Node in find_children("*", "Camera2D", true, false):
		var cam := child as Camera2D
		if cam != null:
			cam.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func _physics_process(delta: float) -> void:
	_update_drop_through_timer(delta)
	_update_jump_timers(delta)

	if input_enabled:
		if _read_jump_just_pressed():
			request_jump()
		if _read_drop_through_just_pressed():
			_try_drop_through()

	_try_consume_buffered_jump()

	var direction := _read_input_direction() if input_enabled else _external_direction
	_set_active_direction(direction)
	velocity.x = _movement_direction * move_speed

	if _drop_through_timer > 0.0 or not is_on_floor():
		var current_gravity := gravity
		if velocity.y < 0.0 and not _is_jump_input_held():
			current_gravity *= jump_cut_gravity_multiplier
		velocity.y = minf(velocity.y + current_gravity * delta, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	move_and_slide()
	_update_landing()
	_update_air_presentation()


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or _is_text_input_focused():
		return
	if event.is_action_pressed("jump"):
		request_jump()
	elif event.is_action_pressed("drop_through"):
		_try_drop_through()


## Supplies horizontal movement when [member input_enabled] is false.
## Values are clamped to -1...1; zero stops Luca and returns to idle.
func set_movement_direction(direction: float) -> void:
	_external_direction = clampf(direction, -1.0, 1.0)


## Compatibility interface for scene-level party controllers. Disabling control
## also clears any externally supplied movement so Luca cannot drift after a swap.
func set_control_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not enabled:
		stop_moving()


func stop_moving() -> void:
	_external_direction = 0.0
	_set_active_direction(0.0)
	velocity.x = 0.0
	_jump_buffer_timer = 0.0
	if not _is_airborne:
		_play_idle()


## Requests a jump using jump buffering and coyote time.
func request_jump() -> void:
	_jump_buffer_timer = jump_buffer_time
	_try_consume_buffered_jump()


## Direct jump command (alias for [method request_jump]).
func jump() -> void:
	request_jump()


func is_airborne() -> bool:
	return _is_airborne


func get_locomotion_state_name() -> StringName:
	match locomotion_state:
		LocomotionState.RUN_START:
			return RUN_START_ANIMATION
		LocomotionState.RUN_LOOP:
			return RUN_LOOP_ANIMATION
		LocomotionState.JUMP:
			return JUMP_ANIMATION
		LocomotionState.FALL:
			return FALL_ANIMATION
		_:
			return IDLE_ANIMATION


func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _try_consume_buffered_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _is_airborne:
		return
	if not is_on_floor() and _coyote_timer <= 0.0:
		return
	_start_jump()
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func _start_jump() -> void:
	_is_airborne = true
	velocity.y = -absf(jump_velocity)
	_play_jump()
	jumped.emit()


func _update_landing() -> void:
	if not _is_airborne or not is_on_floor():
		return
	_is_airborne = false
	velocity.y = 0.0
	if not is_zero_approx(_movement_direction):
		_play_run_loop()
	else:
		_play_idle()
	landed.emit()


func _update_air_presentation() -> void:
	if _is_airborne and velocity.y > 0.0 and locomotion_state == LocomotionState.JUMP:
		_play_fall()


func _read_input_direction() -> float:
	if _is_text_input_focused():
		return 0.0
	var left := Input.is_action_pressed("move_left") or Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A)
	var right := Input.is_action_pressed("move_right") or Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D)
	return float(int(right) - int(left))


func _read_jump_just_pressed() -> bool:
	if _is_text_input_focused():
		return false
	return Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_up")


func _read_drop_through_just_pressed() -> bool:
	if _is_text_input_focused():
		return false
	return Input.is_action_just_pressed("drop_through")


func _is_jump_input_held() -> bool:
	if not input_enabled or _is_text_input_focused():
		return false
	return Input.is_action_pressed("jump") or Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W)


func _set_active_direction(direction: float) -> void:
	direction = clampf(direction, -1.0, 1.0)
	var was_moving := not is_zero_approx(_movement_direction)
	var is_moving := not is_zero_approx(direction)
	_movement_direction = direction

	if is_moving:
		_update_facing(direction)

	if not _is_airborne:
		if is_moving and not was_moving:
			_play_run_start()
			movement_started.emit()
		elif not is_moving and was_moving:
			_play_idle()
			movement_stopped.emit()


func _update_facing(direction: float) -> void:
	animated_sprite.flip_h = direction < 0.0 if source_faces_right else direction > 0.0


func _play_idle() -> void:
	locomotion_state = LocomotionState.IDLE
	animated_sprite.play(IDLE_ANIMATION)


func _play_run_start() -> void:
	locomotion_state = LocomotionState.RUN_START
	animated_sprite.play(RUN_START_ANIMATION)


func _play_run_loop() -> void:
	locomotion_state = LocomotionState.RUN_LOOP
	animated_sprite.play(RUN_LOOP_ANIMATION)


func _play_jump() -> void:
	locomotion_state = LocomotionState.JUMP
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(JUMP_ANIMATION):
		animated_sprite.play(JUMP_ANIMATION)
	else:
		animated_sprite.play(RUN_LOOP_ANIMATION)


func _play_fall() -> void:
	locomotion_state = LocomotionState.FALL
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(FALL_ANIMATION):
		animated_sprite.play(FALL_ANIMATION)
	elif animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(JUMP_ANIMATION):
		animated_sprite.play(JUMP_ANIMATION)
	else:
		animated_sprite.play(RUN_LOOP_ANIMATION)


func _try_drop_through() -> void:
	if _is_airborne or not is_on_floor() or not _is_on_drop_through_platform():
		return
	_drop_through_timer = DROP_THROUGH_DURATION
	collision_mask &= ~DROP_THROUGH_PLATFORM_LAYER
	floor_snap_length = 0.0
	velocity.y = DROP_THROUGH_START_SPEED
	_is_airborne = true
	_play_fall()


func _update_drop_through_timer(delta: float) -> void:
	if _drop_through_timer <= 0.0:
		return
	_drop_through_timer = maxf(_drop_through_timer - delta, 0.0)
	if _drop_through_timer <= 0.0:
		collision_mask |= DROP_THROUGH_PLATFORM_LAYER
		floor_snap_length = _default_floor_snap_length


func _is_on_drop_through_platform() -> bool:
	for collision_index in get_slide_collision_count():
		var collision := get_slide_collision(collision_index)
		var collider := collision.get_collider() as CollisionObject2D
		if collider != null and (collider.collision_layer & DROP_THROUGH_PLATFORM_LAYER) != 0:
			return true
	return false


func _on_animation_finished() -> void:
	if locomotion_state != LocomotionState.RUN_START:
		return
	if is_zero_approx(_movement_direction):
		_play_idle()
	else:
		_play_run_loop()


func _is_text_input_focused() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit

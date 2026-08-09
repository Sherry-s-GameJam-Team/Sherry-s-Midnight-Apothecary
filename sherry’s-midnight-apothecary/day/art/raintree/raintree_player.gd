extends CharacterBody2D

const WALK_JUMP_VELOCITY := -550.0
const RUN_JUMP_VELOCITY := -620.0
const WALK_JUMP_GRAVITY := 950.0
const RUN_JUMP_GRAVITY := 900.0
const MAX_FALL_SPEED := 900.0

const JUMP_CUT_GRAVITY_MULTIPLIER := 2.8

const GROUND_ACCELERATION := 1800.0
const GROUND_FRICTION := 1600.0
const AIR_ACCELERATION := 900.0
const AIR_FRICTION := 500.0

const COYOTE_TIME := 0.12
const JUMP_BUFFER_TIME := 0.12
const DOUBLE_TAP_WINDOW_MS := 260
const ROLL_SPEED_MULTIPLIER := 1.3
const POTION_CAST_RELEASE_TIME := 0.708333

@export_range(0.3, 1.2, 0.01) var character_scale := 0.4
@export_range(50.0, 600.0, 5.0) var walk_speed := 220.0 
@export_range(50.0, 900.0, 5.0) var run_speed := 420.0
@export var initial_facing_right := false

## Optional scene-local perspective scaling. At/under [depth_scale_min_y] the
## character reaches [depth_scale_min_multiplier] of its normal visual size.
@export var depth_scale_enabled := false
@export var depth_scale_max_y := 834.0
@export var depth_scale_min_y := 776.0
@export_range(0.1, 1.0, 0.01) var depth_scale_min_multiplier := 0.9

@onready var sprite: Node2D = $SherryPresentation/SherrySprite
@onready var animation_player: AnimationPlayer = $SherryPresentation/SherryAnimationPlayer
@onready var potion_thrower: Node = get_node_or_null("PotionThrower")

var _state := "idle"
var _transition_target := "idle"
var _horizontal_velocity := 0.0
var _jump_speed_ratio := 0.0
var _is_airborne := false
var _facing_right := false
var _is_rolling := false
var _roll_direction := 0.0
var _last_a_tap_ms := -10000
var _last_d_tap_ms := -10000
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _potion_action_locked := false
var _potion_cast_active := false


func _ready() -> void:
	add_to_group("potion_friendly")
	animation_player.animation_finished.connect(_on_animation_finished)
	floor_snap_length = 12.0
	_facing_right = initial_facing_right
	_apply_visual_scale()
	_play("idle")


func _physics_process(delta: float) -> void:
	var direction := 0.0 if _potion_action_locked else _get_input_direction()
	_update_jump_timers(delta)
	_try_consume_buffered_jump()
	_update_facing(direction)
	_update_ground_transition(direction)
	_update_velocity(delta, direction)
	move_and_slide()
	_apply_visual_scale()
	_update_landing(direction)
	if not _is_transition() and not _is_airborne and not _is_rolling:
		_update_locomotion(direction)
	
	_update_animation_speed()


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo or _is_transition() or _potion_action_locked or _is_text_input_focused():
		return
	if event.is_action_pressed("roll"):
		_try_start_roll("roll")
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		_try_start_roll("move_left" if event.is_action_pressed("move_left") else "move_right")
	if event.is_action_pressed("jump"):
		_request_jump()
	match key_event.keycode:
		KEY_SPACE:
			_play_one_shot("throw")
		KEY_H:
			_play_one_shot("hit")
		KEY_F:
			_play_one_shot("cast")


func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _request_jump() -> void:
	if _is_rolling:
		return
	_jump_buffer_timer = JUMP_BUFFER_TIME
	_try_consume_buffered_jump()


func _try_consume_buffered_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _is_airborne or _is_rolling:
		return
	if not is_on_floor() and _coyote_timer <= 0.0:
		return
	_start_jump()
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func _update_facing(direction: float) -> void:
	if not is_zero_approx(direction) and _facing_right != (direction > 0.0):
		_facing_right = direction > 0.0
		if not _is_transition():
			_play(_state)


func _update_ground_transition(direction: float) -> void:
	if not _is_airborne and _state in ["land", "land_to_idle"] and not is_zero_approx(direction):
		_transition_target = _ground_action_for(direction)
		_play(_transition_target)


func _update_velocity(delta: float, direction: float) -> void:
	if _is_rolling:
		velocity.x = _roll_direction * run_speed * ROLL_SPEED_MULTIPLIER
		_horizontal_velocity = velocity.x
	elif _is_airborne:
		if not is_zero_approx(direction):
			_horizontal_velocity = move_toward(_horizontal_velocity, direction * _current_move_speed(), AIR_ACCELERATION * delta)
		else:
			_horizontal_velocity = move_toward(_horizontal_velocity, 0.0, AIR_FRICTION * delta)
		velocity.x = _horizontal_velocity
	else:
		var target_speed := 0.0
		if _state in ["walk", "run"] or not is_zero_approx(direction):
			target_speed = direction * _current_move_speed()
		
		var accel := GROUND_ACCELERATION if not is_zero_approx(direction) else GROUND_FRICTION
		_horizontal_velocity = move_toward(_horizontal_velocity, target_speed, accel * delta)
		velocity.x = _horizontal_velocity

	if not is_on_floor():
		var gravity := lerpf(WALK_JUMP_GRAVITY, RUN_JUMP_GRAVITY, _jump_speed_ratio)
		
		if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
			gravity *= JUMP_CUT_GRAVITY_MULTIPLIER
			
		velocity.y = minf(velocity.y + gravity * delta, MAX_FALL_SPEED)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _update_landing(direction: float) -> void:
	if not _is_airborne or not is_on_floor():
		return
	velocity.y = 0.0
	_horizontal_velocity = velocity.x
	_jump_speed_ratio = 0.0
	_is_airborne = false
	if _potion_action_locked:
		if not _potion_cast_active:
			_play("idle")
		return
	_transition_target = _ground_action_for(direction)
	_play("land")


func _update_locomotion(direction: float) -> void:
	if is_zero_approx(direction) and is_zero_approx(velocity.x):
		if _state != "idle":
			_play("idle")
		return
	var wants_run := _is_running()
	if _state == "idle" or (_state == "walk" and wants_run) or (_state == "run" and not wants_run):
		_play("run" if wants_run else "walk")


func _update_animation_speed() -> void:
	if _state in ["walk", "run"] and not _is_airborne:
		var target_base_speed := run_speed if _state == "run" else walk_speed
		if target_base_speed > 0.0:
			var speed_ratio := absf(velocity.x) / target_base_speed
			animation_player.speed_scale = maxf(speed_ratio, 0.2)
	else:
		animation_player.speed_scale = 1.0


func _play(action: String) -> void:
	var animation_name := "%s_right" % action if _facing_right else action
	if _state == action and animation_player.current_animation == animation_name and animation_player.is_playing():
		return
	_state = action
	_apply_visual_scale()
	animation_player.play(animation_name)


func _apply_visual_scale() -> void:
	var scale_multiplier := 1.0
	if depth_scale_enabled:
		var y_range := depth_scale_max_y - depth_scale_min_y
		if not is_zero_approx(y_range):
			var depth_progress := clampf((global_position.y - depth_scale_min_y) / y_range, 0.0, 1.0)
			scale_multiplier = lerpf(depth_scale_min_multiplier, 1.0, depth_progress)
	sprite.scale = Vector2.ONE * character_scale * scale_multiplier


func _is_transition() -> bool:
	var animation := animation_player.get_animation(_state)
	return animation == null or animation.loop_mode == Animation.LOOP_NONE


func _on_animation_finished(_animation_name: StringName) -> void:
	if _state == "cast" and _potion_cast_active:
		_potion_cast_active = false
		_potion_action_locked = false
		if potion_thrower != null and potion_thrower.has_method("on_cast_animation_finished"):
			potion_thrower.call("on_cast_animation_finished")
		_play("jump_fall" if _is_airborne else _ground_action_for(_get_input_direction()))
		return
	if _state == "roll":
		_is_rolling = false
		_play(_ground_action_for(_get_input_direction()))
	elif _state == "prejump":
		_play("jump_takeoff")
	elif _state == "jump_takeoff":
		_play("jump_fall")
	elif _state == "land":
		_transition_target = _ground_action_for(_get_input_direction())
		_play(_transition_target if _transition_target in ["walk", "run"] else "land_to_idle")
	elif _state == "land_to_idle":
		_play(_ground_action_for(_get_input_direction()))
	elif _is_transition():
		_play(_transition_target)


func _play_one_shot(action: String) -> void:
	_transition_target = "idle"
	_play(action)


func _start_jump() -> void:
	if _is_airborne or _is_rolling:
		return
	var takeoff_speed := absf(_get_input_direction()) * _current_move_speed()
	_jump_speed_ratio = clampf(takeoff_speed / run_speed, 0.0, 1.0)
	_is_airborne = true
	velocity.y = lerpf(WALK_JUMP_VELOCITY, RUN_JUMP_VELOCITY, _jump_speed_ratio)
	_horizontal_velocity = velocity.x
	_play("prejump")


func _try_start_roll(action_name: StringName) -> void:
	if _is_airborne or _is_rolling or not is_on_floor():
		return
	var direction := 0.0
	if action_name == "move_left":
		direction = -1.0
	elif action_name == "move_right":
		direction = 1.0
	elif action_name == "roll":
		direction = _get_input_direction()
		if is_zero_approx(direction):
			direction = 1.0 if _facing_right else -1.0
		_roll_direction = direction
		_facing_right = _roll_direction > 0.0
		_is_rolling = true
		_play("roll")
		return
	var now := Time.get_ticks_msec()
	var previous_tap := _last_a_tap_ms if action_name == "move_left" else _last_d_tap_ms
	if now - previous_tap > DOUBLE_TAP_WINDOW_MS:
		if action_name == "move_left":
			_last_a_tap_ms = now
		else:
			_last_d_tap_ms = now
		return
	_last_a_tap_ms = -10000
	_last_d_tap_ms = -10000
	_roll_direction = direction
	_facing_right = _roll_direction > 0.0
	_is_rolling = true
	_play("roll")


func _get_input_direction() -> float:
	if _is_text_input_focused():
		return 0.0
	return Input.get_axis("move_left", "move_right")


func _is_running() -> bool:
	return not _is_text_input_focused() and Input.is_action_pressed("move_run")


func _current_move_speed() -> float:
	var base_speed := run_speed if _is_running() else walk_speed
	return base_speed * _active_speed_multiplier()


func _ground_action_for(direction: float) -> String:
	if is_zero_approx(direction):
		return "idle"
	return "run" if _is_running() else "walk"


func can_start_potion_aim(allow_air_aim: bool = false) -> bool:
	if _potion_action_locked or _is_rolling or _potion_cast_active:
		return false
	if not is_on_floor() or _is_airborne:
		return allow_air_aim and _state in ["jump_takeoff", "jump_fall", "fall"]
	return not _is_transition() and _state in ["idle", "walk", "run"]


func set_potion_action_locked(locked: bool) -> void:
	_potion_action_locked = locked
	if locked:
		velocity.x = 0.0
		_horizontal_velocity = 0.0


func is_facing_right() -> bool:
	return _facing_right


func set_potion_aim_facing(facing_right: bool) -> void:
	if _potion_cast_active or _facing_right == facing_right:
		return
	_facing_right = facing_right
	if _potion_action_locked and _state in ["idle", "walk", "run"]:
		_play("idle")


func play_potion_cast() -> void:
	_potion_cast_active = true
	_potion_action_locked = true
	_transition_target = "idle"
	_play("cast")
	get_tree().create_timer(POTION_CAST_RELEASE_TIME, true, false, true).timeout.connect(potion_cast_release, CONNECT_ONE_SHOT)


func potion_cast_release() -> void:
	if _potion_cast_active and potion_thrower != null and potion_thrower.has_method("on_cast_release"):
		potion_thrower.call("on_cast_release")


func apply_potion_effect(effect_id: StringName, context: Dictionary) -> void:
	var shared_player_data := _get_shared_player_data()
	var amount := float(context.get("amount", 0.0))
	match effect_id:
		&"attack":
			var shield := _active_shield()
			var absorbed := minf(shield, amount)
			set_meta("potion_shield", shield - absorbed)
			if shared_player_data != null:
				shared_player_data.health = maxi(shared_player_data.health - roundi(amount - absorbed), 0)
		&"healing":
			if shared_player_data != null:
				shared_player_data.health = mini(shared_player_data.health + roundi(amount), shared_player_data.max_health)
		&"speed":
			set_meta("potion_speed_multiplier", 1.0 + amount)
			set_meta("potion_speed_until_ms", Time.get_ticks_msec() + roundi(float(context.get("duration", 0.0)) * 1000.0))
		&"shield":
			set_meta("potion_shield", float(get_meta("potion_shield", 0.0)) + amount)
			set_meta("potion_shield_until_ms", Time.get_ticks_msec() + roundi(float(context.get("duration", 0.0)) * 1000.0))
		&"mana": set_meta("potion_mana", float(get_meta("potion_mana", 0.0)) + amount)
		&"concealment": set_meta("potion_concealed_until_ms", Time.get_ticks_msec() + roundi(float(context.get("duration", 0.0)) * 1000.0))
		&"purify":
			remove_meta("corrupted")
			remove_meta("negative_statuses")


func _active_speed_multiplier() -> float:
	if Time.get_ticks_msec() > int(get_meta("potion_speed_until_ms", 0)):
		return 1.0
	return maxf(float(get_meta("potion_speed_multiplier", 1.0)), 0.1)


func _active_shield() -> float:
	if Time.get_ticks_msec() > int(get_meta("potion_shield_until_ms", 0)):
		set_meta("potion_shield", 0.0)
		return 0.0
	return maxf(float(get_meta("potion_shield", 0.0)), 0.0)


func _get_shared_player_data() -> PlayerData:
	var current: Node = self
	while current != null and not current.has_method("get_player_data"):
		current = current.get_parent()
	return current.call("get_player_data") as PlayerData if current != null else null


func _is_text_input_focused() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit

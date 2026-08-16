class_name LucaPlayer
extends CharacterBody2D

signal movement_started
signal movement_stopped

enum LocomotionState {
	IDLE,
	RUN_START,
	RUN_LOOP,
}

const IDLE_ANIMATION := &"idle"
const RUN_START_ANIMATION := &"run_start"
const RUN_LOOP_ANIMATION := &"run_loop"

@export_group("Movement")
@export_range(10.0, 1000.0, 5.0, "suffix:px/s") var move_speed := 280.0
@export_range(0.0, 4000.0, 10.0, "suffix:px/s²") var gravity := 1400.0
@export_range(0.0, 4000.0, 10.0, "suffix:px/s") var max_fall_speed := 900.0
@export var input_enabled := true

@export_group("Presentation")
## Luca's source art faces left. Enable this only if the source frames are replaced
## with right-facing art.
@export var source_faces_right := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var locomotion_state := LocomotionState.IDLE
var _movement_direction := 0.0
var _external_direction := 0.0


func _ready() -> void:
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_play_idle()


func _physics_process(delta: float) -> void:
	var direction := _read_input_direction() if input_enabled else _external_direction
	_set_active_direction(direction)
	velocity.x = _movement_direction * move_speed
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	elif velocity.y > 0.0:
		velocity.y = 0.0
	move_and_slide()


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


func get_locomotion_state_name() -> StringName:
	match locomotion_state:
		LocomotionState.RUN_START:
			return RUN_START_ANIMATION
		LocomotionState.RUN_LOOP:
			return RUN_LOOP_ANIMATION
		_:
			return IDLE_ANIMATION


func _read_input_direction() -> float:
	if _is_text_input_focused():
		return 0.0
	var left := Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A)
	var right := Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D)
	return float(int(right) - int(left))


func _set_active_direction(direction: float) -> void:
	direction = clampf(direction, -1.0, 1.0)
	var was_moving := not is_zero_approx(_movement_direction)
	var is_moving := not is_zero_approx(direction)
	_movement_direction = direction

	if is_moving:
		_update_facing(direction)
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

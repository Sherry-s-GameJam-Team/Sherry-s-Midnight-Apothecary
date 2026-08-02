extends Control

const SherryFrames := preload("res://art/characters/sherry/sherry_animation_library.gd")
const STAGE_LEFT := 120.0
const STAGE_RIGHT := 1160.0
const FACE_RIGHT_REQUIRES_FLIP := true

@export_group("Character Tuning")
@export_range(0.3, 1.2, 0.01) var character_scale := 0.4:
	set(value):
		character_scale = value
		if is_instance_valid(sprite):
			sprite.scale = Vector2.ONE * character_scale
@export_range(50.0, 500.0, 5.0) var walk_speed := 50.0
@export_range(50.0, 700.0, 5.0) var run_speed := 200.0

@onready var sprite: AnimatedSprite2D = %SherrySprite
@onready var state_label: Label = %StateLabel
@onready var scale_spin: SpinBox = %ScaleSpin
@onready var walk_speed_spin: SpinBox = %WalkSpeedSpin
@onready var run_speed_spin: SpinBox = %RunSpeedSpin

var _state := "idle"
var _transition_target := "idle"


func _ready() -> void:
	SherryFrames.install_into(sprite.sprite_frames)
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.scale = Vector2.ONE * character_scale
	_sync_debug_panel()
	_play("idle")


func _process(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	if not is_zero_approx(direction):
		sprite.flip_h = direction > 0.0 if FACE_RIGHT_REQUIRES_FLIP else direction < 0.0
	if _state in ["walk", "run"]:
		var speed := run_speed if _state == "run" else walk_speed
		sprite.position.x = clampf(sprite.position.x + direction * speed * delta, STAGE_LEFT, STAGE_RIGHT)
	if not _is_transition():
		_update_locomotion(direction)
	_update_status(direction)


func _update_locomotion(direction: float) -> void:
	if is_zero_approx(direction):
		if _state != "idle":
			_play("idle")
		return
	var wants_run := Input.is_key_pressed(KEY_SHIFT)
	if _state == "idle":
		_play("run" if wants_run else "walk")
	elif _state == "walk" and wants_run:
		_play("run")
	elif _state == "run" and not wants_run:
		_play("walk")


func _play(action: String) -> void:
	if _state == action and sprite.is_playing():
		return
	_state = action
	sprite.play(action)


func _is_transition() -> bool:
	return not SherryFrames.ACTIONS[_state]["loop"]


func _on_animation_finished() -> void:
	if _is_transition():
		_play(_transition_target)


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo or _is_transition():
		return
	match key_event.keycode:
		KEY_SPACE:
			_play_one_shot("throw")
		KEY_H:
			_play_one_shot("hit")
		KEY_F:
			_play_one_shot("fall")


func _play_one_shot(action: String) -> void:
	_transition_target = "idle"
	_play(action)


func _sync_debug_panel() -> void:
	scale_spin.value = character_scale
	walk_speed_spin.value = walk_speed
	run_speed_spin.value = run_speed


func _on_scale_spin_value_changed(value: float) -> void:
	character_scale = value


func _on_walk_speed_spin_value_changed(value: float) -> void:
	walk_speed = value


func _on_run_speed_spin_value_changed(value: float) -> void:
	run_speed = value


func _on_reset_tuning_pressed() -> void:
	character_scale = 0.4
	walk_speed = 50.0
	run_speed = 200.0
	_sync_debug_panel()


func _update_status(direction: float) -> void:
	var direction_text := "静止"
	if direction < 0.0:
		direction_text = "向左"
	elif direction > 0.0:
		direction_text = "向右"
	state_label.text = "当前动作：%s  ·  %s" % [_state, direction_text]

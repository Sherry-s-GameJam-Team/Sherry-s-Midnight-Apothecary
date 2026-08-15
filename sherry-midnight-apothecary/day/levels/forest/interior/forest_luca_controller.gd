class_name ForestLucaController
extends CharacterBody2D

@export var move_speed := 260.0
@export var jump_velocity := -520.0
@export var gravity := 1500.0
var control_enabled := false

func _ready() -> void:
	add_to_group("forest_character")
	add_to_group("luca")

func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	if not enabled:
		velocity.x = 0.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	if control_enabled:
		var left := _strength(&"move_left", &"ui_left")
		var right := _strength(&"move_right", &"ui_right")
		velocity.x = (right - left) * move_speed
		if _pressed(&"jump", &"ui_accept") and is_on_floor():
			velocity.y = jump_velocity
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * 5.0 * delta)
	move_and_slide()

func _strength(primary: StringName, fallback: StringName) -> float:
	if InputMap.has_action(primary):
		return Input.get_action_strength(primary)
	return Input.get_action_strength(fallback)

func _pressed(primary: StringName, fallback: StringName) -> bool:
	if InputMap.has_action(primary):
		return Input.is_action_just_pressed(primary)
	return Input.is_action_just_pressed(fallback)

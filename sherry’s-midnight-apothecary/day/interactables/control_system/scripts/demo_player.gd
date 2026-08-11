class_name DemoPlayer
extends CharacterBody2D

## 极简测试用玩家：左右移动 + 跳跃，用于验证压力板与开关。

@export var speed := 240.0
@export var jump_velocity := -420.0
@export var gravity := 1200.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	move_and_slide()

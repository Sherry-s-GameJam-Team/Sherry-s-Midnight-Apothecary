class_name PushableCrate
extends CharacterBody2D

## Pushable object (bed / crate) on Luca's reality floor.
## Can be pushed horizontally by Luca to lock heavy pressure plates.

@export var push_speed: float = 140.0
@export var gravity: float = 1200.0
@export var friction: float = 700.0

var _is_pushed: bool = false
var _push_direction: float = 0.0


func _ready() -> void:
	add_to_group("pushable_crate")
	collision_layer = 1 | 2
	collision_mask = 1 | 2


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0.0

	if _is_pushed:
		velocity.x = _push_direction * push_speed
		_is_pushed = false
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()

	# Check for player pushing against crate
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider() as Node2D
		if collider != null and collider.name == "Luca":
			var normal := collision.get_normal()
			# Normal points from crate to Luca, so push is in opposite direction (-normal.x)
			if absf(normal.x) > 0.5:
				push_object(-signf(normal.x))


func push_object(direction_x: float) -> void:
	_is_pushed = true
	_push_direction = direction_x

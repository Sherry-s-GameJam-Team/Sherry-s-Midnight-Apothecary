class_name CrescentWaveBullet
extends Area2D

## Horizontal Crescent Wave projectile (剑气.png).
## Fast-moving horizontal slash released after lantern sweep or dream burst.

@export var speed: float = 420.0
@export var damage: float = 18.0
@export var lifetime: float = 4.0

var direction: Vector2 = Vector2.LEFT
var _timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)


func fire(start_pos: Vector2, dir: Vector2) -> void:
	global_position = start_pos
	direction = dir.normalized()
	rotation = direction.angle()
	if sprite != null and dir.x > 0:
		sprite.flip_v = true


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or (body.is_in_group("player") and body.name != "Luca"):
		if body.has_method("apply_damage"):
			body.call("apply_damage", damage, global_position)
		elif body.has_method("take_damage"):
			body.call("take_damage", damage)
		queue_free()
	elif body.name == "WorldBounds":
		queue_free()

class_name MoonOrbBullet
extends Area2D

## Moon Orb Bullet (ball.png) shot in fan bursts.

@export var speed: float = 260.0
@export var damage: float = 14.0
@export var lifetime: float = 6.0

var direction: Vector2 = Vector2.LEFT
var _timer: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)


func fire(start_pos: Vector2, dir: Vector2, custom_speed: float = -1.0) -> void:
	global_position = start_pos
	direction = dir.normalized()
	if custom_speed > 0.0:
		speed = custom_speed
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()

	if sprite != null:
		var pulse := (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
		sprite.scale = Vector2(0.35, 0.35) * lerpf(0.9, 1.15, pulse)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or (body.is_in_group("player") and body.name != "Luca"):
		if body.has_method("apply_damage"):
			body.call("apply_damage", damage, global_position)
		elif body.has_method("take_damage"):
			body.call("take_damage", damage)
		queue_free()
	elif body.name == "Ground" or body.name == "WorldBounds":
		queue_free()

class_name SoulFireBullet
extends Area2D

## Homing Soul Fire projectile (魂火.png).
## Slowly turns toward player for homing_duration before continuing straight and dissipating.

@export var speed: float = 165.0
@export var turn_speed: float = 2.4
@export var damage: float = 15.0
@export var lifetime: float = 4.2
@export var homing_duration: float = 3.0

var velocity: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _target_node: Node2D = null

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)


func fire(start_pos: Vector2, initial_dir: Vector2, target: Node2D = null) -> void:
	global_position = start_pos
	velocity = initial_dir.normalized() * speed
	_target_node = target
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= lifetime:
		_dissipate()
		return

	# Homing steering
	if _timer <= homing_duration:
		var target_pos := Vector2.ZERO
		if _target_node != null and is_instance_valid(_target_node):
			target_pos = _target_node.global_position
		else:
			var root := get_tree().current_scene
			if root != null:
				var pl := root.get_node_or_null("Player") as Node2D
				if pl != null:
					target_pos = pl.global_position

		if target_pos != Vector2.ZERO:
			var desired_dir := (target_pos - global_position).normalized()
			var current_dir := velocity.normalized()
			var new_dir := current_dir.slerp(desired_dir, turn_speed * delta).normalized()
			velocity = new_dir * speed

	global_position += velocity * delta
	rotation = velocity.angle()

	if sprite != null:
		var wobble := sin(_timer * 8.0) * 0.15
		sprite.scale = Vector2(0.3, 0.3) * (1.0 + wobble)


func _dissipate() -> void:
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player" or (body.is_in_group("player") and body.name != "Luca"):
		if body.has_method("apply_damage"):
			body.call("apply_damage", damage, global_position)
		elif body.has_method("take_damage"):
			body.call("take_damage", damage)
		queue_free()
	elif body.name == "Ground" or body.name == "WorldBounds":
		queue_free()

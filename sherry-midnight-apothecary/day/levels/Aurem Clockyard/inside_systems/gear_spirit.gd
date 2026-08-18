class_name GearSpirit
extends CharacterBody2D

@export var move_speed: float = 60.0
@export var patrol_distance: float = 120.0
@export var damage: int = 5

var _direction: float = 1.0
var _origin_x: float = 0.0
var _frozen_timer: float = 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var hitbox: Area2D = get_node_or_null("Hitbox")


func _ready() -> void:
	_origin_x = position.x
	if hitbox != null:
		hitbox.body_entered.connect(_on_hitbox_body_entered)


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: String = String(hit.get("potion_id", ""))
	if "blue" in potion_id or "ice" in potion_id or "cyan" in potion_id:
		_frozen_timer = 4.0
		if sprite != null:
			sprite.modulate = Color(0.4, 0.8, 1.4)
	elif "red" in potion_id or "bomb" in potion_id or "attack" in potion_id:
		# Destroyed
		queue_free()


func _physics_process(delta: float) -> void:
	if _frozen_timer > 0.0:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0 and sprite != null:
			sprite.modulate = Color.WHITE
		return

	# Move back and forth
	velocity.x = _direction * move_speed
	velocity.y += 600.0 * delta # Gravity
	move_and_slide()

	if absf(position.x - _origin_x) > patrol_distance or is_on_wall():
		_direction *= -1.0

	if sprite != null:
		sprite.rotation += _direction * move_speed * 0.05 * delta


func _on_hitbox_body_entered(body: Node2D) -> void:
	if _frozen_timer > 0.0:
		return
	if body.is_in_group("player") or body.name == "Player":
		var env := get_tree().get_first_node_in_group("clocktower_inside")
		if env != null and env.has_method("apply_fall_or_hazard_damage"):
			env.call("apply_fall_or_hazard_damage", damage, "gear_spirit")

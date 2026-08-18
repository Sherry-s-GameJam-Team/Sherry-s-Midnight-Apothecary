class_name RetroClockbird
extends Node2D

@export var fly_speed: float = 70.0
@export var patrol_range: float = 160.0
@export var drop_interval: float = 3.2

var _origin_x: float = 0.0
var _direction: float = -1.0 # Flies backward
var _drop_timer: float = 0.0
var _frozen_timer: float = 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	_origin_x = position.x


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: String = String(hit.get("potion_id", ""))
	if "blue" in potion_id or "ice" in potion_id or "cyan" in potion_id:
		_frozen_timer = 4.0
		if sprite != null:
			sprite.modulate = Color(0.4, 0.8, 1.4)
	elif "red" in potion_id or "bomb" in potion_id or "attack" in potion_id:
		queue_free()


func _physics_process(delta: float) -> void:
	if _frozen_timer > 0.0:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0 and sprite != null:
			sprite.modulate = Color.WHITE
		return

	position.x += _direction * fly_speed * delta
	if absf(position.x - _origin_x) > patrol_range:
		_direction *= -1.0
		if sprite != null:
			sprite.flip_h = _direction > 0.0

	_drop_timer += delta
	if _drop_timer >= drop_interval:
		_drop_timer = 0.0
		_drop_bolt()


func _drop_bolt() -> void:
	var bolt := Area2D.new()
	bolt.collision_layer = 0
	bolt.collision_mask = 1 | 2
	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	col.shape = circle
	bolt.add_child(col)

	var spr := Sprite2D.new()
	spr.modulate = Color(1.0, 0.6, 0.2)
	bolt.add_child(spr)

	get_parent().add_child(bolt)
	bolt.global_position = global_position

	bolt.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") or b.name == "Player":
			var env := get_tree().get_first_node_in_group("clocktower_inside")
			if env != null and env.has_method("apply_fall_or_hazard_damage"):
				env.call("apply_fall_or_hazard_damage", 5, "clockbird_bolt")
			bolt.queue_free()
		elif b is StaticBody2D or b is AnimatableBody2D:
			bolt.queue_free()
	)

	var tween := bolt.create_tween()
	tween.tween_property(bolt, "position:y", bolt.position.y + 400.0, 1.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(bolt.queue_free)

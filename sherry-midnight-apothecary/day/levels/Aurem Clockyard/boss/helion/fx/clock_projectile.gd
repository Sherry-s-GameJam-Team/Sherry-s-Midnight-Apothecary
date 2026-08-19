extends Area2D
class_name HelionClockProjectile

@export var gravity: float = 0.0

var velocity: Vector2 = Vector2.ZERO
var _damage: int = 1

func _ready():
	collision_layer = 0
	collision_mask = 1 # Player mask
	
	var shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(20, 6)
	shape.shape = rect_shape
	add_child(shape)
	
	body_entered.connect(_on_body_entered)
	
	var timer = get_tree().create_timer(5.0)
	timer.timeout.connect(queue_free)

func launch(direction: Vector2, speed: float, damage: int):
	velocity = direction.normalized() * speed
	_damage = damage
	rotation = direction.angle()

func _physics_process(delta):
	velocity.y += gravity * delta
	global_position += velocity * delta
	if velocity.length_squared() > 0:
		rotation = velocity.angle()
	queue_redraw()

func _draw():
	draw_rect(Rect2(-10, -3, 20, 6), Color(0.9, 0.8, 0.2, 1.0))

func _on_body_entered(body: Node2D):
	if body.is_in_group("player") or body.name == "Player":
		apply_damage(body)
		queue_free()

func apply_damage(_body: Node2D):
	var node = self
	while node:
		if node.has_method("apply_player_damage"):
			node.apply_player_damage(_damage, self)
			return
		elif node.has_method("apply_fall_or_hazard_damage"):
			node.apply_fall_or_hazard_damage(_damage, self)
			return
		node = node.get_parent()

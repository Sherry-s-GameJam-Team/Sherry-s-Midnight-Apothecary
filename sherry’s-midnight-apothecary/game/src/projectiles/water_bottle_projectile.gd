extends Area2D

@export var speed: float = 520.0
@export var arc_velocity: float = -180.0
@export var arc_gravity: float = 760.0
@export var life_time: float = 1.6

var velocity: Vector2 = Vector2.ZERO
var thrower: Node = null
var _has_hit: bool = false


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func launch(direction: Vector2, owner_node: Node = null) -> void:
	var launch_direction: Vector2 = direction.normalized()
	if launch_direction == Vector2.ZERO:
		launch_direction = Vector2.RIGHT
	thrower = owner_node
	velocity = launch_direction * speed
	velocity.y += arc_velocity
	rotation = velocity.angle()


func _physics_process(delta: float) -> void:
	life_time -= delta
	if life_time <= 0.0:
		queue_free()
		return

	velocity.y += arc_gravity * delta
	position += velocity * delta
	rotation = velocity.angle()


func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return

	var target: Node = area.get_parent()
	if target != null and target.has_method("take_water_hit"):
		_has_hit = true
		target.call("take_water_hit")
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _has_hit or body == thrower:
		return
	_has_hit = true
	queue_free()

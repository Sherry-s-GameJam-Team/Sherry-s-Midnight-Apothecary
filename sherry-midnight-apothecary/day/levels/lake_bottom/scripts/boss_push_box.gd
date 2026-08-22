class_name LakeBossPushBox
extends RigidBody2D

@export var player_push_force := 9000.0
@export var maximum_push_speed := 430.0

var _nearby_players: Array[CharacterBody2D] = []


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	var material := PhysicsMaterial.new()
	material.friction = 0.15
	material.bounce = 0.0
	physics_material_override = material
	var push_area := Area2D.new()
	push_area.name = "PushAssistArea"
	push_area.collision_layer = 0
	push_area.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(230.0, 210.0)
	collision.shape = shape
	push_area.add_child(collision)
	add_child(push_area)
	push_area.body_entered.connect(_on_push_area_body_entered)
	push_area.body_exited.connect(_on_push_area_body_exited)


func _physics_process(delta: float) -> void:
	var retained_players: Array[CharacterBody2D] = []
	for player in _nearby_players:
		if is_instance_valid(player):
			retained_players.append(player)
	_nearby_players = retained_players
	for player in _nearby_players:
		var intended_direction := signf(player.velocity.x)
		if is_zero_approx(intended_direction):
			intended_direction = Input.get_axis(&"move_left", &"move_right")
		var box_direction := signf(global_position.x - player.global_position.x)
		if is_zero_approx(intended_direction) or intended_direction != box_direction:
			continue
		apply_central_force(Vector2(box_direction * player_push_force, 0.0))
		linear_velocity.x = move_toward(linear_velocity.x, box_direction * maximum_push_speed, player_push_force * delta)
	linear_velocity.x = clampf(linear_velocity.x, -maximum_push_speed, maximum_push_speed)


func _on_push_area_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player") and body not in _nearby_players:
		_nearby_players.append(body)


func _on_push_area_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_nearby_players.erase(body)

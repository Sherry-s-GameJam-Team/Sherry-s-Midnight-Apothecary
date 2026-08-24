class_name PotionProjectile
extends CharacterBody2D

signal broken(impact_point: Vector2, impact_normal: Vector2)
## Emitted when the projectile directly collides with a receiver implementing
## `receive_potion_hit(hit: Dictionary)` on its collision node or an ancestor.
signal direct_hit(receiver: Object, hit: Dictionary)

var gravity := 1250.0
var payload: Dictionary = {}
var potion: PotionData
var effect_tuning: PotionEffectTuning
var bottle_color := Color.WHITE
var max_lifetime := 6.0
var projectile_radius := 12.0
var _elapsed := 0.0
var _has_broken := false

@onready var bottle_sprite: Sprite2D = $BottleSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func configure(initial_velocity: Vector2, shared_payload: Dictionary, definition: PotionData, throw_tuning: PotionThrowTuning, shared_effect_tuning: PotionEffectTuning) -> void:
	velocity = initial_velocity
	payload = shared_payload.duplicate(true)
	potion = definition
	gravity = throw_tuning.projectile_gravity
	collision_mask = throw_tuning.projectile_collision_mask
	effect_tuning = shared_effect_tuning
	projectile_radius = throw_tuning.projectile_radius
	max_lifetime = throw_tuning.projectile_max_lifetime
	bottle_color = PotionColorResolver.resolve(potion, payload)
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = throw_tuning.projectile_radius
	if bottle_sprite != null:
		bottle_sprite.texture = PotionSvgRenderer.get_bottle_texture(bottle_color, 72, 1.0, float(payload.get("potency", 1.0)))


func _ready() -> void:
	if collision_shape != null and collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = projectile_radius
	if potion != null and bottle_sprite != null:
		bottle_sprite.texture = PotionSvgRenderer.get_bottle_texture(bottle_color, 72, 1.0, float(payload.get("potency", 1.0)))


func _physics_process(delta: float) -> void:
	if _has_broken:
		return
	_elapsed += delta
	if _elapsed >= max_lifetime:
		_break(global_position, Vector2.UP)
		return
	velocity.y += gravity * delta
	rotation = velocity.angle() + PI * 0.5

	var from_pos := global_position
	var motion := velocity * delta
	var to_pos := from_pos + motion

	var space := get_world_2d().direct_space_state
	if space != null:
		var excludes: Array[RID] = [get_rid()]
		for p in get_tree().get_nodes_in_group("player"):
			if p is CollisionObject2D:
				excludes.append((p as CollisionObject2D).get_rid())
		for l in get_tree().get_nodes_in_group("forest_luca_runtime"):
			if l is CollisionObject2D:
				excludes.append((l as CollisionObject2D).get_rid())

		# 1. Raycast for fast Area2D / Body collision along the trajectory line
		var query := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.collision_mask = 0xFFFFFFFF
		query.exclude = excludes

		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var collider: Object = hit.get("collider")
			var hit_pos: Vector2 = hit.get("position", to_pos)
			var hit_normal: Vector2 = hit.get("normal", -velocity.normalized())
			if collider != null and collider != self:
				_break(hit_pos, hit_normal, collider)
				return

		# 2. Shape overlap check for Area2D targets (e.g. boss weakpoints / rings)
		var circle := CircleShape2D.new()
		circle.radius = projectile_radius
		var shape_query := PhysicsShapeQueryParameters2D.new()
		shape_query.shape = circle
		shape_query.transform = Transform2D(0.0, to_pos)
		shape_query.collide_with_areas = true
		shape_query.collide_with_bodies = false
		shape_query.collision_mask = 0xFFFFFFFF
		shape_query.exclude = excludes
		var shape_hits := space.intersect_shape(shape_query, 1)
		if not shape_hits.is_empty():
			var collider: Object = shape_hits[0].get("collider")
			if collider != null and collider != self:
				_break(to_pos, -velocity.normalized(), collider)
				return

	var collision := move_and_collide(motion)
	if collision != null:
		_break(collision.get_position(), collision.get_normal(), collision.get_collider())


func _break(point: Vector2, normal: Vector2, direct_collider: Object = null) -> void:
	if _has_broken:
		return
	_has_broken = true
	velocity = Vector2.ZERO
	if bottle_sprite != null:
		bottle_sprite.visible = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	_notify_direct_hit(direct_collider, point, normal)
	if effect_tuning != null and get_parent() != null:
		var executor := PotionEffectExecutor.new()
		executor.tuning = effect_tuning
		get_parent().add_child(executor)
		executor.execute(potion, payload, point, normal, self)
		executor.queue_free()
	if get_parent() != null:
		var splash := PotionSplash.new()
		get_parent().add_child(splash)
		splash.global_position = point
		splash.setup(bottle_color)
	broken.emit(point, normal)
	queue_free()


func _notify_direct_hit(collider: Object, point: Vector2, normal: Vector2) -> void:
	var receiver := _find_direct_hit_receiver(collider)
	if receiver == null:
		return
	var hit := {
		"potion": potion,
		"potion_id": potion.id if potion != null else &"",
		"payload": payload.duplicate(true),
		"effect_multiplier": float(payload.get("effect_stack_multiplier", 1.0)),
		"consumed_dose": float(payload.get("consumed_dose", 0.0)),
		"impact_point": point,
		"impact_normal": normal,
		"projectile": self,
	}
	receiver.call("receive_potion_hit", hit)
	direct_hit.emit(receiver, hit)


func _find_direct_hit_receiver(collider: Object) -> Object:
	var current := collider as Node
	while current != null:
		if current.has_method("receive_potion_hit"):
			return current
		current = current.get_parent()
	return null

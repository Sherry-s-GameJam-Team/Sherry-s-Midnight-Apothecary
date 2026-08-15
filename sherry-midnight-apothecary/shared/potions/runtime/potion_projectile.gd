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
	if collision_shape.shape is CircleShape2D:
		(collision_shape.shape as CircleShape2D).radius = projectile_radius
	if potion != null:
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
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		_break(collision.get_position(), collision.get_normal(), collision.get_collider())


func _break(point: Vector2, normal: Vector2, direct_collider: Object = null) -> void:
	if _has_broken:
		return
	_has_broken = true
	velocity = Vector2.ZERO
	bottle_sprite.visible = false
	collision_shape.set_deferred("disabled", true)
	_notify_direct_hit(direct_collider, point, normal)
	var executor := PotionEffectExecutor.new()
	executor.tuning = effect_tuning
	get_parent().add_child(executor)
	executor.execute(potion, payload, point, normal, self)
	executor.queue_free()
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

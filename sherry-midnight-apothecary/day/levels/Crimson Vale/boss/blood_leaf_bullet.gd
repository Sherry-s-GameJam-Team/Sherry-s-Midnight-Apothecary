class_name BloodLeafBullet
extends Area2D

## Phase 3 Boss Bullet: Single collision blood leaf projectile with Red-to-Yellow color variation and frame-perfect core hitbox detection.

@export var speed: float = 320.0
@export var damage: float = 1.0
@export var lifetime: float = 4.5

var velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _has_hit: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail: GPUParticles2D = $Trail


func _ready() -> void:
	add_to_group("hazard")
	add_to_group("blood_leaf_bullet")
	add_to_group("potion_target")
	collision_layer = 1 | 2
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_apply_color_variation()


func _apply_color_variation() -> void:
	# Random hue between Red (0.0), Vermilion (0.04), Orange (0.08), and Golden Yellow (0.14)
	var hue := randf_range(0.0, 0.14)
	var sat := randf_range(0.85, 1.0)
	var val := randf_range(1.4, 2.0)
	var leaf_color := Color.from_hsv(hue, sat, val, 1.0)
	if sprite != null:
		sprite.modulate = leaf_color
	if trail != null and trail.process_material is ParticleProcessMaterial:
		var mat := (trail.process_material as ParticleProcessMaterial).duplicate() as ParticleProcessMaterial
		mat.color = Color.from_hsv(hue, 0.8, 1.1, 0.75)
		trail.process_material = mat


func launch(dir: Vector2, spd: float = 320.0) -> void:
	velocity = dir.normalized() * spd
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	position += velocity * delta
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	# Frame-perfect check against player hitbox core
	_check_core_overlap()


func _check_core_overlap() -> void:
	if _has_hit:
		return

	for core in get_tree().get_nodes_in_group("player_hitbox_core"):
		if core is Node2D and is_instance_valid(core) and bool(core.get("is_active")) and core.visible:
			var dist := global_position.distance_to(core.global_position)
			var threshold: float = float(core.get("core_radius")) + 12.0 # ~36px
			if dist <= threshold:
				_deliver_hit(core)
				return


func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return

	if body is CharacterBody2D and (body.is_in_group("player") or body.name == "Player"):
		var hitbox_core := body.get_node_or_null("HitboxCore")
		if hitbox_core != null and hitbox_core.visible and bool(hitbox_core.get("is_active")):
			# Check distance to core
			if global_position.distance_to(hitbox_core.global_position) <= 36.0:
				_deliver_hit(body)
		else:
			_deliver_hit(body)


func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return

	if area.name == "HurtboxArea" or area.is_in_group("player_core_hurtbox"):
		_deliver_hit(area.get_parent())


func _deliver_hit(target: Node) -> void:
	if _has_hit:
		return
	_has_hit = true

	var knockback := velocity.normalized() * 160.0
	if target != null:
		if target.has_method("receive_hit"):
			target.call("receive_hit", damage, knockback)
		elif target.has_method("play_hazard_hit"):
			target.call("play_hazard_hit", knockback)

	queue_free()


func dispel() -> void:
	if _has_hit:
		return
	_has_hit = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


func receive_potion_hit(_hit: Dictionary) -> void:
	dispel()

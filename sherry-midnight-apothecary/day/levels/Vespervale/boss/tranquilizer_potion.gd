class_name TranquilizerPotion
extends Area2D

## Tranquilizer potion thrown in arc by Director Boss.
## Spawns a lingering purple sedative mist on ground contact that slows / damages the player.

@export var speed: float = 380.0
@export var arc_gravity: float = 620.0
@export var mist_duration: float = 2.8
@export var damage: float = 20.0

var velocity: Vector2 = Vector2.ZERO
var _exploded: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var mist_area: Area2D = $MistArea
@onready var mist_particles: CPUParticles2D = $MistParticles


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	if mist_area != null:
		mist_area.monitoring = false
		mist_area.body_entered.connect(_on_mist_body_entered)


func launch(start_pos: Vector2, target_pos: Vector2, arc_height: float = 120.0) -> void:
	global_position = start_pos
	var diff := target_pos - start_pos
	var time := clampf(diff.length() / speed, 0.6, 1.4)

	# Calculate initial velocity for parabola
	velocity.x = diff.x / time
	velocity.y = (diff.y - 0.5 * arc_gravity * time * time) / time


func _physics_process(delta: float) -> void:
	if _exploded:
		return

	velocity.y += arc_gravity * delta
	global_position += velocity * delta
	if sprite != null:
		sprite.rotation += 12.0 * delta

	# Auto ground trigger if Y >= 640
	if global_position.y >= 640.0:
		_explode()


func _on_body_entered(body: Node2D) -> void:
	if _exploded:
		return
	if body.name == "Ground" or body.name == "WorldBounds" or body.is_in_group("ground") or body.name == "Player":
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true

	if sprite != null:
		sprite.visible = false

	if mist_particles != null:
		mist_particles.emitting = true

	if mist_area != null:
		mist_area.monitoring = true

	# Fade out and free after mist duration
	var tw := create_tween()
	tw.tween_interval(mist_duration - 0.5)
	if mist_particles != null:
		tw.tween_property(mist_particles, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _on_mist_body_entered(body: Node2D) -> void:
	if body.name == "Player" or (body.is_in_group("player") and body.name != "Luca"):
		if body.has_method("apply_damage"):
			body.call("apply_damage", damage, global_position)
		elif body.has_method("take_damage"):
			body.call("take_damage", damage)

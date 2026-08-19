class_name DreamGraspHandUnit
extends Area2D

## Visual and HitBox unit for an individual Dream Grasp Hand eruption.
## Uses the 24 frames from dream_grasp_hands_frames_24:
## - Frames 0–7: Lurk / ground hint (Hitbox OFF)
## - Frames 8–13: Lock telegraph (Hitbox OFF)
## - Frames 14–17: Hands surge upward (Hitbox grows upward)
## - Frames 18–22: Full grasp (Hitbox ACTIVE, single-tick damage)
## - Frame 23: Clench pause & Retract

signal unit_completed
signal hit_delivered(body: Node2D)

@export var damage: int = 1
@export var is_secondary: bool = false

var _has_dealt_damage: bool = false
var _is_cancelled: bool = false

@onready var animated_sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var particles: GPUParticles2D = get_node_or_null("DreamParticles")
@onready var telegraph_ring: Node2D = get_node_or_null("TelegraphRing")


func _ready() -> void:
	add_to_group("hazard")
	add_to_group("dream_grasp_hand")
	collision_layer = 0
	collision_mask = 1 | 2 # Sherry (Player) and Luca
	body_entered.connect(_on_body_entered)

	if collision_shape != null:
		collision_shape.disabled = true

	if animated_sprite != null:
		animated_sprite.frame_changed.connect(_on_frame_changed)
		animated_sprite.animation_finished.connect(_on_animation_finished)


func start_lock_and_erupt(lock_time: float) -> void:
	if _is_cancelled:
		return

	# 1. Lock phase telegraph
	visible = true
	if telegraph_ring != null:
		telegraph_ring.visible = true
		telegraph_ring.modulate.a = 0.0
		var tw := create_tween()
		if tw != null:
			tw.tween_property(telegraph_ring, "modulate:a", 0.9, lock_time * 0.4)
			tw.tween_property(telegraph_ring, "scale", Vector2(1.15, 0.6), lock_time * 0.6)

	if animated_sprite != null:
		animated_sprite.frame = 8
		animated_sprite.pause()

	# Wait for lock duration before erupting
	if not is_inside_tree() or get_tree() == null:
		return
	await get_tree().create_timer(lock_time).timeout
	if _is_cancelled or not is_inside_tree():
		return

	# 2. Erupt phase
	if telegraph_ring != null:
		var tw_ring := create_tween()
		if tw_ring != null:
			tw_ring.tween_property(telegraph_ring, "modulate:a", 0.0, 0.15)

	if particles != null:
		particles.emitting = true

	if animated_sprite != null:
		animated_sprite.play("erupt")


func _on_frame_changed() -> void:
	if animated_sprite == null:
		animated_sprite = get_node_or_null("AnimatedSprite2D")
	if collision_shape == null:
		collision_shape = get_node_or_null("CollisionShape2D")
	if animated_sprite == null or collision_shape == null:
		return

	var f := animated_sprite.frame
	# Frame 0-13: Hitbox OFF
	if f <= 13:
		collision_shape.disabled = true
	# Frame 14-17: Rising hands (Hitbox activates and scales)
	elif f <= 17:
		collision_shape.disabled = false
		collision_shape.position = Vector2(0, -20.0 - float(f - 14) * 8.0)
	# Frame 18-22: Full grasp (Hitbox full height)
	elif f <= 22:
		collision_shape.disabled = false
		collision_shape.position = Vector2(0, -45.0)
	# Frame 23: Clench pause
	else:
		collision_shape.disabled = true


func _on_body_entered(body: Node2D) -> void:
	if _has_dealt_damage or _is_cancelled:
		return

	# Verify body is Sherry or Luca
	var is_player := (body.name == "Player" or body.is_in_group("player") or body.name == "Luca" or body.is_in_group("luca"))
	if not is_player:
		return

	_has_dealt_damage = true
	hit_delivered.emit(body)

	# 1. Deliver damage
	var env := _find_environment()
	if env != null and env.has_method("apply_player_damage"):
		env.call("apply_player_damage", damage, &"dream_grasp_hand")
	elif body.has_method("take_damage"):
		body.call("take_damage", damage)

	# 2. Snare / hit reaction
	if body.has_method("_play"):
		body.call("_play", "hit")

	# 3. Purple impact burst
	if particles != null:
		particles.amount = 30
		particles.restart()


func _on_animation_finished() -> void:
	# Retract and fade out
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func() -> void:
		unit_completed.emit()
		queue_free()
	)


func cancel_and_dissipate() -> void:
	_is_cancelled = true
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _find_environment() -> Node:
	var cur: Node = self
	while cur != null:
		if cur is DayLevelEnvironment:
			return cur
		cur = cur.get_parent()
	return null

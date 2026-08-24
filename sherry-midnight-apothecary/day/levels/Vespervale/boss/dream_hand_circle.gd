class_name DreamHandCircle
extends Area2D

## Telegraph ground circle for Dream Grasp summoning attack.
## Shows warning ring for telegraph_duration, then erupts with upward grasp attack.

@export var telegraph_duration: float = 0.85
@export var damage: float = 16.0

var _is_erupted: bool = false

@onready var circle_sprite: Sprite2D = $CircleSprite
@onready var hit_shape: CollisionShape2D = $CollisionShape2D
@onready var claw_visual: Polygon2D = $ClawVisual


func _ready() -> void:
	collision_layer = 0
	collision_mask = 3
	monitoring = false
	if claw_visual != null:
		claw_visual.visible = false

	_start_telegraph()


func _start_telegraph() -> void:
	if circle_sprite != null:
		circle_sprite.scale = Vector2.ZERO
		circle_sprite.modulate = Color(1.2, 0.4, 1.4, 0.9)
		var tw := create_tween()
		tw.tween_property(circle_sprite, "scale", Vector2(0.45, 0.45), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(circle_sprite, "modulate:a", 0.4, 0.3)
		tw.tween_property(circle_sprite, "modulate:a", 1.0, 0.3)
		tw.tween_callback(_erupt)
	else:
		get_tree().create_timer(telegraph_duration).timeout.connect(_erupt)


func _erupt() -> void:
	if _is_erupted:
		return
	_is_erupted = true
	monitoring = true

	if claw_visual != null:
		claw_visual.visible = true
		claw_visual.position.y = 20.0
		var tw := create_tween()
		tw.tween_property(claw_visual, "position:y", -110.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(claw_visual, "modulate:a", 0.0, 0.25)

	# Check overlapping bodies
	for body in get_overlapping_bodies():
		if body.name == "Player" or (body.is_in_group("player") and body.name != "Luca"):
			if body.has_method("apply_damage"):
				body.call("apply_damage", damage, global_position)
			elif body.has_method("take_damage"):
				body.call("take_damage", damage)

	var fade_tw := create_tween()
	if circle_sprite != null:
		fade_tw.tween_property(circle_sprite, "scale", Vector2(0.6, 0.6), 0.2)
		fade_tw.parallel().tween_property(circle_sprite, "modulate:a", 0.0, 0.2)
	fade_tw.tween_callback(queue_free)


func _on_body_entered(body: Node2D) -> void:
	if not _is_erupted:
		return
	if body.name == "Player" or (body.is_in_group("player") and body.name != "Luca"):
		if body.has_method("apply_damage"):
			body.call("apply_damage", damage, global_position)
		elif body.has_method("take_damage"):
			body.call("take_damage", damage)

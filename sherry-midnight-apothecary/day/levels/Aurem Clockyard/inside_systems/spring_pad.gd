class_name ClockworkSpringPad
extends Node2D

## Interactive Spring Bounce Pad for Clocktower climbing platformer
## Bounces the player upwards (or at an angle) with satisfying squash & stretch animation.

signal bounced(body: Node2D)

@export var launch_force_y: float = 750.0
@export var launch_force_x: float = 0.0
@export var cooldown: float = 0.2
@export var auto_pulse_boost: float = 1.2

var _on_cooldown: bool = false

@onready var spring_sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var bounce_area: Area2D = get_node_or_null("BounceArea")


func _ready() -> void:
	if bounce_area != null:
		bounce_area.body_entered.connect(_on_body_entered)


func trigger_bounce(body: CharacterBody2D, boost: float = 1.0) -> void:
	if _on_cooldown or body == null:
		return
	_on_cooldown = true

	body.velocity.y = -launch_force_y * boost
	if absf(launch_force_x) > 0.1:
		body.velocity.x = launch_force_x * boost

	bounced.emit(body)

	var tree: SceneTree = get_tree() if is_inside_tree() else null
	if tree != null:
		var audio: Node = tree.get_first_node_in_group("clocktower_audio")
		if audio != null and audio.has_method("play_gear_clack"):
			audio.call("play_gear_clack")

	# Squash and stretch animation
	if spring_sprite != null:
		var tween := create_tween()
		if tween != null:
			tween.tween_property(spring_sprite, "scale", Vector2(1.3, 0.4), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(spring_sprite, "scale", Vector2(0.85, 1.35), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(spring_sprite, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)

	if tree != null:
		tree.create_timer(cooldown).timeout.connect(func() -> void:
			_on_cooldown = false
		)
	else:
		_on_cooldown = false


func trigger_room_pulse() -> void:
	if spring_sprite != null:
		var tween := create_tween()
		if tween != null:
			tween.tween_property(spring_sprite, "scale", Vector2(1.2, 0.6), 0.08)
			tween.tween_property(spring_sprite, "scale", Vector2(1.0, 1.0), 0.15)


func receive_potion_hit(hit: Dictionary) -> void:
	var potion_id: String = String(hit.get("potion_id", ""))
	if "orange" in potion_id or "speed" in potion_id:
		# Supercharge next bounce
		launch_force_y *= 1.4
	elif "blue" in potion_id or "ice" in potion_id:
		_on_cooldown = true
		if spring_sprite != null:
			spring_sprite.modulate = Color(0.4, 0.8, 1.4)
		if is_inside_tree():
			var tree := get_tree()
			if tree != null:
				tree.create_timer(3.0).timeout.connect(func() -> void:
					_on_cooldown = false
					if spring_sprite != null:
						spring_sprite.modulate = Color.WHITE
				)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.is_in_group("player") or body.name == "Player"):
		trigger_bounce(body as CharacterBody2D, 1.0)

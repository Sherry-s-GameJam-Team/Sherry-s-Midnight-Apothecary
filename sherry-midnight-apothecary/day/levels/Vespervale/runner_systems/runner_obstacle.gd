class_name RunnerObstacle
extends Area2D

## Obstacle placed on upper or lower runner tracks.
## Inflicts damage/stumble if the respective character collides with it.

enum TargetTrack { LOWER_SHERRY, UPPER_LUCA, BOTH }

@export var target_track: TargetTrack = TargetTrack.LOWER_SHERRY
@export var damage: int = 1
@export var obstacle_name: String = "Obstacle"

var _has_hit: bool = false

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	add_to_group("hazard")
	add_to_group("runner_obstacle")
	collision_layer = 1 | 2
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return

	var is_sherry := (body.name == "Player" or body.is_in_group("player"))
	var is_luca := (body.name == "Luca" or body.is_in_group("luca"))

	var matches_track := false
	match target_track:
		TargetTrack.LOWER_SHERRY:
			matches_track = is_sherry
		TargetTrack.UPPER_LUCA:
			matches_track = is_luca
		TargetTrack.BOTH:
			matches_track = is_sherry or is_luca

	if matches_track:
		_trigger_hit(body)


func _trigger_hit(body: Node2D) -> void:
	_has_hit = true

	# Trigger character hit stumble animation via runner controller
	var ctrl := _find_runner_controller()
	if ctrl != null and ctrl.has_method("notify_character_hit"):
		ctrl.call("notify_character_hit", body)
	elif body.has_method("_play"):
		body.call("_play", "hit")

	# Character stumble flash
	if body is Node2D:
		var tw := create_tween()
		tw.tween_property(body, "modulate", Color(1.8, 0.4, 0.4, 1.0), 0.08)
		tw.tween_property(body, "modulate", Color.WHITE, 0.2)

	# Deliver damage to environment
	var env := _find_environment()
	if env != null and env.has_method("apply_player_damage"):
		env.call("apply_player_damage", damage, &"runner_obstacle")
	elif body.has_method("take_damage"):
		body.call("take_damage", damage)

	# Purple dream dissolve burst on obstacle impact
	if sprite != null:
		var tw2 := create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(sprite, "modulate", Color(1.8, 0.6, 2.2, 0.35), 0.15)
		tw2.tween_property(sprite, "scale", sprite.scale * 1.12, 0.15)
		tw2.chain().tween_property(sprite, "modulate:a", 0.3, 0.2)


func _find_runner_controller() -> Node:
	var cur: Node = self
	while cur != null:
		var ctrl := cur.get_node_or_null("RunnerController")
		if ctrl != null:
			return ctrl
		cur = cur.get_parent()
	return null


func _find_environment() -> Node:
	var cur: Node = self
	while cur != null:
		if cur is DayLevelEnvironment:
			return cur
		cur = cur.get_parent()
	return null

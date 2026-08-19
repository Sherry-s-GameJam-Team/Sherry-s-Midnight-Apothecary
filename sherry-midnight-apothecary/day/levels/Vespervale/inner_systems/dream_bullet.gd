class_name DreamBullet
extends Area2D

## Lightweight glowing dream projectile fired from ward windows, doors, and spikes.
## Inflicts damage on active player character; non-controlled character is immune.
## Gets absorbed by pillar shelters.

@export var speed: float = 240.0
@export var damage: int = 1
@export var lifetime: float = 5.0
@export var bullet_color: Color = Color(0.78, 0.45, 1.0, 0.95)
@export var glow_color: Color = Color(0.6, 0.2, 0.9, 0.4)
@export var radius: float = 8.0

var velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _has_hit: bool = false
var _pulse_phase: float = 0.0


func _ready() -> void:
	add_to_group("hazard")
	add_to_group("dream_bullet")
	collision_layer = 1 | 2
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_pulse_phase = randf() * TAU


func launch(dir: Vector2, spd: float = 240.0) -> void:
	velocity = dir.normalized() * spd
	rotation = dir.angle()


func _physics_process(delta: float) -> void:
	if _has_hit:
		return

	position += velocity * delta
	_age += delta
	_pulse_phase += delta * 8.0
	queue_redraw()

	if _age >= lifetime:
		_fade_out_and_destroy()
		return

	_check_core_overlap()


func _draw() -> void:
	if _has_hit:
		return
	var p_scale := 1.0 + sin(_pulse_phase) * 0.15
	# Outer soft glow
	draw_circle(Vector2.ZERO, (radius + 6.0) * p_scale, glow_color)
	# Main body
	draw_circle(Vector2.ZERO, radius * p_scale, bullet_color)
	# Bright core
	draw_circle(Vector2.ZERO, radius * 0.45, Color(1.0, 0.9, 1.0, 0.95))
	# Small trailing flare
	var tail_dir := -velocity.normalized() * (radius * 1.2)
	draw_line(Vector2.ZERO, tail_dir, Color(0.9, 0.5, 1.0, 0.6), 3.0)


func _check_core_overlap() -> void:
	if _has_hit:
		return
	for core in get_tree().get_nodes_in_group("player_hitbox_core"):
		if core is Node2D and is_instance_valid(core) and bool(core.get("is_active")) and core.visible:
			var parent := core.get_parent()
			if _is_character_active(parent):
				if global_position.distance_to(core.global_position) <= 24.0:
					_deliver_hit(core)
					return


func _on_body_entered(body: Node2D) -> void:
	if _has_hit:
		return
	if body.is_in_group("pillar_shelter") or body.name.begins_with("Pillar"):
		_fade_out_and_destroy()
		return
	if body is CharacterBody2D and (body.is_in_group("player") or body.name == "Player" or body.name == "Luca"):
		if _is_character_active(body):
			_deliver_hit(body)


func _on_area_entered(area: Area2D) -> void:
	if _has_hit:
		return
	if area.is_in_group("pillar_shelter"):
		_fade_out_and_destroy()
		return
	if area.name == "HurtboxArea" or area.is_in_group("player_core_hurtbox"):
		var parent := area.get_parent()
		if _is_character_active(parent):
			_deliver_hit(parent)


func _is_character_active(body: Node) -> bool:
	if body == null:
		return true
	# Check PartyController if available
	var party := _find_party_controller()
	if party != null and party.has_method("is_character_active"):
		return bool(party.call("is_character_active", body))
	# Fallback checks
	if body.get("input_enabled") != null and not bool(body.get("input_enabled")):
		return false
	if body.get("_dialogue_locked") != null and bool(body.get("_dialogue_locked")):
		return false
	return true


func _deliver_hit(target: Node) -> void:
	if _has_hit:
		return
	_has_hit = true

	var env := _find_environment()
	if env != null and env.has_method("apply_player_damage"):
		env.call("apply_player_damage", damage, &"dream_bullet")
	elif target.has_method("take_damage"):
		target.call("take_damage", damage)

	_fade_out_and_destroy()


func _fade_out_and_destroy() -> void:
	_has_hit = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)


func _find_party_controller() -> Node:
	var cur: Node = self
	while cur != null:
		var party := cur.get_node_or_null("InnerPartyController")
		if party != null:
			return party
		cur = cur.get_parent()
	return null


func _find_environment() -> Node:
	var cur: Node = self
	while cur != null:
		if cur is DayLevelEnvironment:
			return cur
		cur = cur.get_parent()
	return null

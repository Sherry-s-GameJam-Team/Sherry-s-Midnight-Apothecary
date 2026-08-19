class_name RollingStretcher
extends CharacterBody2D

## Rolling hospital stretcher that moves along the lower corridor during Reality Intrusion,
## and locks in place while emitting vertical pulse bullets during Dream state.

@export var move_speed: float = 80.0
@export var patrol_distance: float = 180.0
@export var damage: int = 1
@export var bullet_scene: PackedScene = preload("res://day/levels/Vespervale/inner_systems/dream_bullet.tscn")

var _is_dream: bool = false
var _origin_x: float = 0.0
var _direction: float = 1.0
var _pulse_timer: float = 0.0
var _speed_multiplier: float = 1.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var hurt_area: Area2D = get_node_or_null("HurtArea")


func _ready() -> void:
	_origin_x = position.x
	if hurt_area != null:
		hurt_area.add_to_group("hazard")
		hurt_area.body_entered.connect(_on_hurt_body_entered)

	var manager := _find_shift_manager()
	if manager != null:
		manager.dream_state_changed.connect(_on_dream_state_changed)
		_set_dream_state(manager.is_in_dream())


func set_slowed(slowed: bool = true) -> void:
	_speed_multiplier = 0.55 if slowed else 1.0


func _physics_process(delta: float) -> void:
	if not _is_dream:
		# Patrol in Reality state
		position.x += _direction * (move_speed * _speed_multiplier) * delta
		if position.x > _origin_x + patrol_distance:
			_direction = -1.0
		elif position.x < _origin_x - patrol_distance:
			_direction = 1.0
	else:
		# Pulse bullets in Dream state
		_pulse_timer -= delta
		if _pulse_timer <= 0.0:
			_pulse_timer = 2.2
			_emit_pulse_bullet()


func _emit_pulse_bullet() -> void:
	if bullet_scene == null:
		return
	var b := bullet_scene.instantiate() as DreamBullet
	if b == null:
		return
	b.global_position = global_position + Vector2(0, -20)
	var world := get_tree().current_scene
	if world != null:
		world.add_child(b)
	else:
		get_parent().add_child(b)
	b.launch(Vector2.UP.rotated(randf_range(-0.35, 0.35)), 180.0)


func _on_dream_state_changed(in_dream: bool) -> void:
	_set_dream_state(in_dream)


func _set_dream_state(in_dream: bool) -> void:
	_is_dream = in_dream
	_pulse_timer = 0.5
	if sprite != null:
		var target_color := Color(0.9, 0.5, 1.1, 1.0) if in_dream else Color(1.0, 1.0, 1.0, 1.0)
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", target_color, 0.3)


func _on_hurt_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.is_in_group("player") or body.name == "Player" or body.name == "Luca"):
		var party := _find_party_controller()
		if party != null and party.has_method("is_character_active"):
			if not bool(party.call("is_character_active", body)):
				return # Inactive character is safe from collision hazard

		var env := _find_environment()
		if env != null and env.has_method("apply_player_damage"):
			env.call("apply_player_damage", damage, &"rolling_stretcher")
		elif body.has_method("take_damage"):
			body.call("take_damage", damage)


func _find_party_controller() -> Node:
	var cur: Node = self
	while cur != null:
		var party := cur.get_node_or_null("InnerPartyController")
		if party != null:
			return party
		cur = cur.get_parent()
	return null


func _find_shift_manager() -> DreamShiftManager:
	var cur: Node = self
	while cur != null:
		var mgr := cur.get_node_or_null("DreamShiftManager") as DreamShiftManager
		if mgr != null:
			return mgr
		cur = cur.get_parent()
	return null


func _find_environment() -> Node:
	var cur: Node = self
	while cur != null:
		if cur is DayLevelEnvironment:
			return cur
		cur = cur.get_parent()
	return null

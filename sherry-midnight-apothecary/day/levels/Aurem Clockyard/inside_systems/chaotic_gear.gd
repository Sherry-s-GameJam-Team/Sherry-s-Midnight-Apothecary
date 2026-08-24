class_name ChaoticHazardGear
extends AnimatableBody2D

## Chaotic moving gear hazard for Floor 2 (Gear Well)
## Moves in disordered/chaotic trajectories, spins violently, deals collision damage,
## and can be frozen with ice potions or stabilized by Calibration Node 2.

enum MotionType {
	CHAOTIC_BOUNCE,
	ELLIPTICAL_SWEEP,
	VERTICAL_SURGE,
}

@export var motion_type: MotionType = MotionType.CHAOTIC_BOUNCE
@export var base_speed: float = 180.0
@export var damage: int = 15
@export var is_stabilized: bool = false
@export var bounds_min: Vector2 = Vector2(100, -800)
@export var bounds_max: Vector2 = Vector2(1100, -100)
@export var sweep_radius: Vector2 = Vector2(250, 120)
@export var sweep_frequency: float = 1.2
@export var initial_direction: Vector2 = Vector2(1.0, 0.7)

var _velocity: Vector2 = Vector2.ZERO
var _center_pos: Vector2 = Vector2.ZERO
var _time_elapsed: float = 0.0
var _is_frozen: bool = false
var _frozen_timer: float = 0.0
var _slowdown_timer: float = 0.0
var _damage_cooldown_timer: float = 0.0

@onready var gear_sprite: Sprite2D = get_node_or_null("GearSprite")
@onready var hitbox: Area2D = get_node_or_null("Hitbox")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	sync_to_physics = true
	_center_pos = position
	_velocity = initial_direction.normalized() * base_speed
	if hitbox != null:
		hitbox.body_entered.connect(_on_hitbox_body_entered)


func set_stabilized(val: bool) -> void:
	is_stabilized = val
	if is_stabilized:
		if gear_sprite != null:
			gear_sprite.modulate = Color(1.0, 0.9, 0.5)


func set_slowdown(duration: float = 6.0) -> void:
	_slowdown_timer = duration


func receive_potion_hit(hit: Dictionary) -> void:
	if PotionCapabilityResolver.hit_has_capability(hit, &"freeze"):
		_is_frozen = true
		_frozen_timer = 4.5
		if gear_sprite != null:
			gear_sprite.modulate = Color(0.4, 0.8, 1.4)
	elif PotionCapabilityResolver.hit_has_capability(hit, &"impact"):
		_velocity = -_velocity * 1.5
		_slowdown_timer = 2.5
	elif PotionCapabilityResolver.hit_has_capability(hit, &"activation"):
		_slowdown_timer = 5.0


func _physics_process(delta: float) -> void:
	if _damage_cooldown_timer > 0.0:
		_damage_cooldown_timer -= delta

	if _is_frozen:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0:
			_is_frozen = false
			if gear_sprite != null:
				gear_sprite.modulate = Color.WHITE if not is_stabilized else Color(1.0, 0.9, 0.5)
		return

	if _slowdown_timer > 0.0:
		_slowdown_timer -= delta

	var current_speed := base_speed
	if is_stabilized:
		current_speed *= 0.3
	elif _slowdown_timer > 0.0:
		current_speed *= 0.25

	_time_elapsed += delta

	# Spin visual
	if gear_sprite != null:
		var spin_dir := 1.0 if not is_stabilized else 0.5
		gear_sprite.rotation += (current_speed / 40.0) * spin_dir * delta

	# Disordered movement based on type
	match motion_type:
		MotionType.CHAOTIC_BOUNCE:
			if not is_stabilized:
				var move_step := _velocity.normalized() * current_speed * delta
				position += move_step

				# Chaotic boundary bouncing with slight random angle perturbation
				if position.x <= bounds_min.x:
					position.x = bounds_min.x
					_velocity.x = absf(_velocity.x) + randf_range(-10.0, 10.0)
				elif position.x >= bounds_max.x:
					position.x = bounds_max.x
					_velocity.x = -absf(_velocity.x) + randf_range(-10.0, 10.0)

				if position.y <= bounds_min.y:
					position.y = bounds_min.y
					_velocity.y = absf(_velocity.y) + randf_range(-10.0, 10.0)
				elif position.y >= bounds_max.y:
					position.y = bounds_max.y
					_velocity.y = -absf(_velocity.y) + randf_range(-10.0, 10.0)
			else:
				# Smooth calm hover when stabilized
				position = _center_pos + Vector2(sin(_time_elapsed * 1.5) * 30.0, cos(_time_elapsed * 1.5) * 15.0)

		MotionType.ELLIPTICAL_SWEEP:
			var freq := sweep_frequency if not is_stabilized else sweep_frequency * 0.4
			var offset_x := cos(_time_elapsed * freq) * sweep_radius.x
			var offset_y := sin(_time_elapsed * freq * 1.7) * sweep_radius.y
			position = _center_pos + Vector2(offset_x, offset_y)

		MotionType.VERTICAL_SURGE:
			var surge_y := sin(_time_elapsed * sweep_frequency * 2.0) * sweep_radius.y
			var surge_x := sin(_time_elapsed * 0.7) * 40.0
			position = _center_pos + Vector2(surge_x, surge_y)

	# Active overlap damage check
	if _damage_cooldown_timer <= 0.0 and hitbox != null and not is_stabilized:
		for overlapping in hitbox.get_overlapping_bodies():
			if overlapping.is_in_group("player") or overlapping.name == "Player":
				_try_damage_player(overlapping)
				break


func _on_hitbox_body_entered(body: Node2D) -> void:
	_try_damage_player(body)


func _try_damage_player(body: Node2D) -> void:
	if is_stabilized or _is_frozen or _damage_cooldown_timer > 0.0:
		return

	if body.is_in_group("player") or body.name == "Player":
		_damage_cooldown_timer = 0.8
		_apply_damage_to_player()


func _apply_damage_to_player() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree != null:
		var audio: Node = tree.get_first_node_in_group("clocktower_audio")
		if audio != null and audio.has_method("play_gear_grind_warning"):
			audio.call("play_gear_grind_warning")

		var env := tree.get_first_node_in_group("clocktower_inside")
		if env != null and env.has_method("apply_fall_or_hazard_damage"):
			env.call("apply_fall_or_hazard_damage", damage, "chaotic_gear_collision")
		elif env != null and env.has_method("apply_player_damage"):
			env.call("apply_player_damage", damage, &"chaotic_gear_collision")
		else:
			var current: Node = self
			var damage_applied := false
			while current != null:
				if current.has_method("apply_player_damage"):
					current.call("apply_player_damage", damage, &"chaotic_gear_collision")
					damage_applied = true
					break
				current = current.get_parent()
			if not damage_applied:
				var runtime := get_node_or_null("/root/DayRuntime")
				if runtime != null and runtime.has_method("apply_player_damage"):
					runtime.call("apply_player_damage", damage, &"chaotic_gear_collision")

class_name GearPlatform
extends AnimatableBody2D

enum RotationMode {
	CLOCKWISE,
	COUNTER_CLOCKWISE,
	OVERSPEED,
	STALLED,
}

@export var mode: RotationMode = RotationMode.CLOCKWISE
@export var base_speed: float = 1.2
@export var radius: float = 80.0
@export var is_sync_controlled: bool = false
@export var sync_target_angle: float = 0.0

var _current_angle: float = 0.0
var _frozen_timer: float = 0.0
var _is_synchronized: bool = false
var _sync_timer: float = 0.0

@onready var gear_sprite: Sprite2D = get_node_or_null("GearSprite")


func _ready() -> void:
	sync_to_physics = true


func set_synchronized(active: bool, duration: float = 6.0) -> void:
	if not is_sync_controlled:
		return
	_is_synchronized = active
	_sync_timer = duration if active else 0.0
	if active:
		_current_angle = sync_target_angle
		rotation = _current_angle
		if gear_sprite != null:
			gear_sprite.modulate = Color(1.2, 1.1, 0.4)
	else:
		if gear_sprite != null:
			gear_sprite.modulate = Color.WHITE


func receive_potion_hit(hit: Dictionary) -> void:
	if PotionCapabilityResolver.hit_has_capability(hit, &"freeze"):
		# Freeze gear in place for 4.0s
		_frozen_timer = 4.0
		if gear_sprite != null:
			gear_sprite.modulate = Color(0.4, 0.8, 1.4)
	elif PotionCapabilityResolver.hit_has_capability(hit, &"machine_drive"):
		# Temporarily speed up or align
		set_synchronized(true, 4.0)


func _physics_process(delta: float) -> void:
	if _frozen_timer > 0.0:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0 and gear_sprite != null:
			gear_sprite.modulate = Color.WHITE
		return

	if _is_synchronized:
		_sync_timer -= delta
		if _sync_timer <= 0.0:
			set_synchronized(false)
		return

	var speed_multiplier := 1.0
	match mode:
		RotationMode.CLOCKWISE:
			speed_multiplier = 1.0
		RotationMode.COUNTER_CLOCKWISE:
			speed_multiplier = -1.0
		RotationMode.OVERSPEED:
			speed_multiplier = 3.5
		RotationMode.STALLED:
			speed_multiplier = sin(Time.get_ticks_msec() * 0.003) * 0.4

	_current_angle += base_speed * speed_multiplier * delta
	rotation = _current_angle

class_name WardBulletLauncher
extends Node2D

## Emits rhythmic dream bullet patterns from hospital windows, ward doors, and node emitters.
## Automatically activates during Dream state and pauses during Reality state.
## Supports temporary disabling via switches or potion strikes.

enum LaunchMode { HORIZONTAL, FAN_3WAY, DOWNWARD, AIMED_RADIAL }

@export var launch_mode: LaunchMode = LaunchMode.HORIZONTAL
@export var bullet_scene: PackedScene = preload("res://day/levels/Vespervale/inner_systems/dream_bullet.tscn")
@export var fire_direction: Vector2 = Vector2.LEFT
@export var fire_interval: float = 1.6
@export var initial_delay: float = 0.2
@export var bullet_speed: float = 230.0
@export var fan_spread_angle_deg: float = 30.0
@export var is_active_in_reality: bool = false
@export var glow_color: Color = Color(0.8, 0.4, 1.0, 0.7)

var _is_dream: bool = false
var _fire_timer: float = 0.0
var _disabled_timer: float = 0.0
var _is_manually_disabled: bool = false

@onready var indicator: Sprite2D = get_node_or_null("Indicator")


func _ready() -> void:
	_fire_timer = initial_delay
	_pulse_indicator(false)
	var manager := _find_shift_manager()
	if manager != null:
		manager.dream_state_changed.connect(_on_dream_state_changed)
		_is_dream = manager.is_in_dream()
		_pulse_indicator(_is_dream)


func disable_temporary(duration: float) -> void:
	_disabled_timer = maxf(_disabled_timer, duration)
	_pulse_indicator(false)


func set_launcher_disabled(disabled: bool) -> void:
	_is_manually_disabled = disabled
	_pulse_indicator(not disabled and (_is_dream or is_active_in_reality))


func _physics_process(delta: float) -> void:
	if _disabled_timer > 0.0:
		_disabled_timer -= delta
		if _disabled_timer <= 0.0:
			_pulse_indicator(_is_dream or is_active_in_reality)
		return

	if _is_manually_disabled:
		return

	var active := _is_dream or is_active_in_reality
	if not active:
		return

	_fire_timer -= delta

	# Telegraph warning: illuminate indicator 0.4s before firing
	if _fire_timer <= 0.4 and indicator != null:
		indicator.modulate = Color(1.2, 0.7, 1.3, 0.95)

	if _fire_timer <= 0.0:
		_fire_timer = fire_interval
		_fire_volley()


func _fire_volley() -> void:
	if bullet_scene == null:
		return

	match launch_mode:
		LaunchMode.HORIZONTAL:
			_spawn_bullet(fire_direction.normalized())
		LaunchMode.DOWNWARD:
			_spawn_bullet(Vector2.DOWN)
		LaunchMode.FAN_3WAY:
			var base_dir := fire_direction.normalized()
			var spread := deg_to_rad(fan_spread_angle_deg)
			_spawn_bullet(base_dir)
			_spawn_bullet(base_dir.rotated(spread))
			_spawn_bullet(base_dir.rotated(-spread))
		LaunchMode.AIMED_RADIAL:
			for i in range(4):
				var angle := float(i) * (PI * 0.5) + randf_range(-0.1, 0.1)
				_spawn_bullet(Vector2.RIGHT.rotated(angle))

	_pulse_indicator(true)


func _spawn_bullet(dir: Vector2) -> void:
	var bullet := bullet_scene.instantiate() as DreamBullet
	if bullet == null:
		return
	bullet.global_position = global_position
	var world := get_tree().current_scene
	if world != null:
		world.add_child(bullet)
	else:
		get_parent().add_child(bullet)
	bullet.launch(dir, bullet_speed)


func _on_dream_state_changed(in_dream: bool) -> void:
	_is_dream = in_dream
	_fire_timer = initial_delay
	_pulse_indicator((in_dream or is_active_in_reality) and _disabled_timer <= 0.0 and not _is_manually_disabled)


func _pulse_indicator(active: bool) -> void:
	if indicator != null:
		var target_color := glow_color if active else Color(0.4, 0.35, 0.5, 0.25)
		var tw := create_tween()
		tw.tween_property(indicator, "modulate", target_color, 0.3)


func _find_shift_manager() -> DreamShiftManager:
	var cur: Node = self
	while cur != null:
		var mgr := cur.get_node_or_null("DreamShiftManager") as DreamShiftManager
		if mgr != null:
			return mgr
		cur = cur.get_parent()
	return null

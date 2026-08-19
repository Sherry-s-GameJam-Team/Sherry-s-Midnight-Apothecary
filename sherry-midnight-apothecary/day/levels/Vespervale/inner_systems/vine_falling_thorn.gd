class_name VineFallingThorn
extends Node2D

## Ceiling hanging purple bell vine that sways during telegraph and drops falling thorns during Dream state.
## Can be stunned/disabled temporarily when Sherry hits an associated LightTarget with a potion.

@export var drop_interval: float = 2.4
@export var initial_delay: float = 0.5
@export var bullet_scene: PackedScene = preload("res://day/levels/Vespervale/inner_systems/dream_bullet.tscn")

var _is_dream: bool = false
var _is_telegraphing: bool = false
var _drop_timer: float = 0.0
var _sway_time: float = 0.0
var _stun_timer: float = 0.0

@onready var vine_sprite: Sprite2D = get_node_or_null("VineSprite")


func _ready() -> void:
	_drop_timer = initial_delay
	var manager := _find_shift_manager()
	if manager != null:
		manager.dream_state_changed.connect(_on_dream_state_changed)
		manager.state_telegraph_started.connect(_on_telegraph_started)
		_is_dream = manager.is_in_dream()


func stun(duration: float) -> void:
	_stun_timer = maxf(_stun_timer, duration)
	if vine_sprite != null:
		var tw := create_tween()
		tw.tween_property(vine_sprite, "modulate", Color(0.4, 0.4, 0.4, 0.4), 0.2)


func _physics_process(delta: float) -> void:
	if _stun_timer > 0.0:
		_stun_timer -= delta
		if _stun_timer <= 0.0 and vine_sprite != null:
			var target_color := Color(0.95, 0.5, 1.2, 1.0) if _is_dream else Color(0.7, 0.65, 0.8, 0.7)
			vine_sprite.modulate = target_color
		return

	_sway_time += delta
	# Pre-drop shake telegraph (0.5s before drop)
	var is_about_to_drop := (_drop_timer <= 0.5 and _is_dream)
	var sway_speed := 12.0 if is_about_to_drop else (8.0 if _is_telegraphing else (4.0 if _is_dream else 1.5))
	var sway_mag := 0.3 if is_about_to_drop else (0.25 if _is_telegraphing else (0.15 if _is_dream else 0.05))
	rotation = sin(_sway_time * sway_speed) * sway_mag

	if not _is_dream:
		return

	_drop_timer -= delta
	if _drop_timer <= 0.0:
		_drop_timer = drop_interval
		_drop_thorn()


func _drop_thorn() -> void:
	if bullet_scene == null:
		return
	var b := bullet_scene.instantiate() as DreamBullet
	if b == null:
		return
	b.global_position = global_position + Vector2(0, 30)
	b.bullet_color = Color(0.9, 0.35, 0.7, 0.95)
	b.radius = 7.0
	var world := get_tree().current_scene
	if world != null:
		world.add_child(b)
	else:
		get_parent().add_child(b)
	b.launch(Vector2.DOWN, 280.0)


func _on_telegraph_started(_entering_dream: bool) -> void:
	_is_telegraphing = true
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(func() -> void: _is_telegraphing = false)


func _on_dream_state_changed(in_dream: bool) -> void:
	_is_dream = in_dream
	_is_telegraphing = false
	_drop_timer = initial_delay
	if vine_sprite != null and _stun_timer <= 0.0:
		var target_color := Color(0.95, 0.5, 1.2, 1.0) if in_dream else Color(0.7, 0.65, 0.8, 0.7)
		var tw := create_tween()
		tw.tween_property(vine_sprite, "modulate", target_color, 0.3)


func _find_shift_manager() -> DreamShiftManager:
	var cur: Node = self
	while cur != null:
		var mgr := cur.get_node_or_null("DreamShiftManager") as DreamShiftManager
		if mgr != null:
			return mgr
		cur = cur.get_parent()
	return null

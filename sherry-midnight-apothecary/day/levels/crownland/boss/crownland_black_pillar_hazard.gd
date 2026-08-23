class_name CrownlandBlackPillarHazard
extends Node2D
## 黑魔法柱 地面危险物 / Black Magic Pillar Hazard (Stage 1 Attack B)
## Sequence: magic circle warning → pillar rises (hitbox active) → lingers → despawn.
## Uses: 魔法阵.png (warning) + Crownland pillar.png (pillar visual).
## Single-hit-per-player guard built in.

@export var magic_circle_texture: Texture2D  ## 魔法阵.png
@export var pillar_texture: Texture2D         ## 黑魔法柱子.png

@export var warning_color: Color = Color(0.6, 0.0, 0.1, 0.7)

enum PillarState { WARNING, RISING, LINGERING, DESPAWNING }

var _state: PillarState = PillarState.WARNING
var _damage: int = 12
var _warn_time: float = 1.0
var _rise_time: float = 0.18
var _linger_time: float = 0.4
var _timer: float = 0.0
var _has_hit_player: bool = false
var _active: bool = false

var _warn_sprite: Sprite2D
var _pillar_sprite: Sprite2D
var _pillar_area: Area2D
var _pillar_shape: CollisionShape2D
var _pulse_tween: Tween

const PILLAR_TEXTURE_PATH := "res://day/levels/crownland/pillar.png"
const PILLAR_VISUAL_SCALE := Vector2(0.10, 0.10)
const PILLAR_REST_Y := -77.0
const PILLAR_BURIED_Y := 80.0


func _ready() -> void:
	# Warning magic circle
	_warn_sprite = Sprite2D.new()
	_warn_sprite.name = "WarnSprite"
	if magic_circle_texture != null:
		_warn_sprite.texture = magic_circle_texture
	add_child(_warn_sprite)

	# Pillar sprite (starts invisible, below floor)
	_pillar_sprite = Sprite2D.new()
	_pillar_sprite.name = "PillarSprite"
	_pillar_sprite.visible = false
	# Attack hazards always use the Crownland purification-pillar art, even if
	# an older director instance still holds a stale texture reference.
	pillar_texture = load(PILLAR_TEXTURE_PATH) as Texture2D
	_pillar_sprite.texture = pillar_texture
	_pillar_sprite.scale = PILLAR_VISUAL_SCALE
	_pillar_sprite.position.y = PILLAR_BURIED_Y
	add_child(_pillar_sprite)

	# Hitbox (disabled until rising)
	_pillar_area = Area2D.new()
	_pillar_area.collision_layer = 0
	_pillar_area.collision_mask = 1
	_pillar_area.monitoring = false
	add_child(_pillar_area)

	_pillar_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 120)
	_pillar_shape.shape = rect
	_pillar_shape.position = Vector2(0, -60)
	_pillar_area.add_child(_pillar_shape)

	_pillar_area.body_entered.connect(_on_body_entered)


## Spawn this hazard at a given world position.
func spawn_at(world_pos: Vector2, damage: int, warn_time: float = 1.0) -> void:
	global_position = world_pos
	_damage = damage
	_warn_time = warn_time
	_active = true

	# Pulse the warning circle
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	if _pulse_tween != null:
		_pulse_tween.tween_property(_warn_sprite, "modulate:a", 0.9, 0.25)
		_pulse_tween.tween_property(_warn_sprite, "modulate:a", 0.3, 0.25)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_timer += delta
	match _state:
		PillarState.WARNING:
			if _timer >= _warn_time:
				_begin_rise()
		PillarState.RISING:
			# Rise from beneath the floor into its aligned resting position.
			var t := clampf((_timer - _warn_time) / _rise_time, 0.0, 1.0)
			_pillar_sprite.position.y = lerpf(PILLAR_BURIED_Y, PILLAR_REST_Y, t)
			if t >= 1.0:
				_begin_linger()
		PillarState.LINGERING:
			if _timer >= _warn_time + _rise_time + _linger_time:
				_begin_despawn()
		PillarState.DESPAWNING:
			pass


func _begin_rise() -> void:
	_state = PillarState.RISING
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_warn_sprite.visible = false
	_pillar_sprite.visible = true
	_pillar_sprite.position.y = PILLAR_BURIED_Y
	_pillar_area.monitoring = true
	_pillar_shape.disabled = false


func _begin_linger() -> void:
	_state = PillarState.LINGERING
	_pillar_sprite.position.y = PILLAR_REST_Y


func _begin_despawn() -> void:
	_state = PillarState.DESPAWNING
	_active = false
	_pillar_area.monitoring = false
	var tween := create_tween()
	if tween != null:
		tween.tween_property(_pillar_sprite, "modulate:a", 0.0, 0.2)
		tween.tween_callback(queue_free)
	else:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _has_hit_player:
		return
	if body.is_in_group("player") or body.name == "Player":
		_has_hit_player = true
		_apply_damage()


func _apply_damage() -> void:
	var node: Node = self
	while node != null:
		if node.has_method("apply_player_damage"):
			node.call("apply_player_damage", _damage, self)
			return
		if node.has_method("apply_fall_or_hazard_damage"):
			node.call("apply_fall_or_hazard_damage", _damage, "crownland_pillar_hazard")
			return
		node = node.get_parent()


func cleanup() -> void:
	_active = false
	queue_free()


func _draw() -> void:
	if magic_circle_texture == null and _state == PillarState.WARNING:
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 16, warning_color, 3.0)
	if pillar_texture == null and (_state == PillarState.RISING or _state == PillarState.LINGERING):
		draw_rect(Rect2(-20, -120, 40, 120), Color(0.15, 0.0, 0.3, 0.85))

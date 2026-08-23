class_name CrownlandTrackingOrb
extends CrownlandProjectileBase
## 追踪黑球 / Tracking Dark Orb
## Three size variants: SMALL (no track), MEDIUM (track 0.8s), LARGE (track 1.2s).
## Behavior: track → lock → dash. Never permanent tracking.
## Textures: 左向弹幕小.png / 左向弹幕中.png / 左向弹幕1.png

enum OrbSize { SMALL, MEDIUM, LARGE }

@export var orb_size: OrbSize = OrbSize.SMALL
@export var texture_small: Texture2D
@export var texture_medium: Texture2D
@export var texture_large: Texture2D

# Configured by spawn call
var _track_time: float = 0.0
var _track_speed: float = 0.0
var _dash_speed: float = 0.0
var _dash_delay: float = 0.15

var _state: int = 0   # 0=tracking, 1=locked_waiting, 2=dashing
var _velocity: Vector2 = Vector2.ZERO
var _timer: float = 0.0
var _player: Node2D = null

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false

	if _sprite == null:
		var s := Sprite2D.new()
		s.name = "Sprite2D"
		add_child(s)
		_sprite = s

	if _shape == null:
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = _get_collision_radius()
		cs.shape = circle
		add_child(cs)
		_shape = cs

	_apply_texture()
	_init_base(0)


func _get_collision_radius() -> float:
	match orb_size:
		OrbSize.SMALL:  return 8.0
		OrbSize.MEDIUM: return 14.0
		OrbSize.LARGE:  return 22.0
	return 8.0


func _apply_texture() -> void:
	if _sprite == null:
		return
	var tex: Texture2D = null
	match orb_size:
		OrbSize.SMALL:  tex = texture_small
		OrbSize.MEDIUM: tex = texture_medium
		OrbSize.LARGE:  tex = texture_large
	if tex != null:
		_sprite.texture = tex


func _draw() -> void:
	var radius := _get_collision_radius()
	var col: Color
	match orb_size:
		OrbSize.SMALL:  col = Color(0.3, 0.0, 0.6, 0.9)
		OrbSize.MEDIUM: col = Color(0.5, 0.0, 0.5, 0.9)
		OrbSize.LARGE:  col = Color(0.7, 0.0, 0.3, 0.9)
		_:              col = Color(0.4, 0.0, 0.5, 0.9)
	if _sprite == null or _sprite.texture == null:
		draw_circle(Vector2.ZERO, radius, col)


## Main spawn method. Called by BattleDirector.
## player_node: may be null — orb will try to find player.
func launch(
		size: OrbSize,
		track_time: float,
		track_speed: float,
		dash_speed: float,
		damage: int,
		dash_delay: float = 0.15,
		player_node: Node2D = null) -> void:
	orb_size = size
	_track_time = track_time
	_track_speed = track_speed
	_dash_speed = dash_speed
	_dash_delay = dash_delay
	_damage = damage
	_player = player_node
	_apply_texture()
	if _shape != null:
		var circle := _shape.shape as CircleShape2D
		if circle != null:
			circle.radius = _get_collision_radius()
	_active = true
	if _track_time <= 0.0:
		# SMALL: no tracking, pick a direction toward player and go straight
		_lock_velocity()
		_state = 2


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_timer += delta
	match _state:
		0:  # tracking
			_do_tracking(delta)
			if _timer >= _track_time:
				_lock_velocity()
				_state = 1
				_timer = 0.0
		1:  # locked, waiting for dash
			if _timer >= _dash_delay:
				_state = 2
		2:  # dashing
			global_position += _velocity * delta
	super._physics_process(delta)
	queue_redraw()


func _do_tracking(delta: float) -> void:
	_find_player()
	if _player == null or not is_instance_valid(_player):
		return
	var dir := (_player.global_position - global_position).normalized()
	global_position += dir * _track_speed * delta


func _lock_velocity() -> void:
	_find_player()
	if _player != null and is_instance_valid(_player):
		_velocity = (_player.global_position - global_position).normalized() * _dash_speed
	else:
		_velocity = Vector2.LEFT * _dash_speed


func _find_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if is_inside_tree() and get_tree() != null:
		_player = get_tree().get_first_node_in_group("player") as Node2D


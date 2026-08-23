class_name CrownlandNeedleDrop
extends CrownlandProjectileBase
## 竖针坠落 / Vertical Needle Drop
## Warning line at top → high-speed fall → linger → despawn.
## Three visual variants via texture array (randomly assigned).
## Textures: 竖向两面针.png / 竖向两面针2.png / 竖向两面针3.png

@export var needle_textures: Array[Texture2D] = []
@export var warning_color: Color = Color(0.8, 0.1, 0.1, 0.5)

enum NeedleState { WARNING, FALLING, LINGERING, DONE }

var _state: NeedleState = NeedleState.WARNING
var _fall_speed: float = 900.0
var _linger_time: float = 0.25
var _timer: float = 0.0
var _warn_time: float = 0.7
var _warn_line_alpha: float = 0.5
var _target_y: float = 0.0   # world-space Y of floor

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _warn_line: Line2D = $WarnLine


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = false   # off until falling/lingering
	monitorable = false

	# Warning line
	if _warn_line == null:
		var l := Line2D.new()
		l.name = "WarnLine"
		l.width = 3.0
		l.default_color = warning_color
		add_child(l)
		_warn_line = l
	_warn_line.clear_points()
	_warn_line.add_point(Vector2.ZERO)
	_warn_line.add_point(Vector2(0, -900))  # upward
	_warn_line.show()

	# Sprite
	if _sprite == null:
		var s := Sprite2D.new()
		s.name = "Sprite2D"
		s.visible = false
		add_child(s)
		_sprite = s
	if not needle_textures.is_empty():
		_sprite.texture = needle_textures[randi() % needle_textures.size()]

	# Collision
	if _shape == null:
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16, 60)
		cs.shape = rect
		add_child(cs)
		_shape = cs

	_init_base(0)


## Called by BattleDirector.
## spawn_x: world X, floor_y: world Y of landing point,
## warn_time: seconds, fall_speed, linger_time, damage.
func spawn_at(
		spawn_x: float,
		floor_y: float,
		warn_time: float,
		fall_speed: float,
		linger_time: float,
		damage: int,
		start_y: float = -9999.0) -> void:
	_damage = damage
	_fall_speed = fall_speed
	_linger_time = linger_time
	_warn_time = warn_time
	_target_y = floor_y
	# Position the warning indicator at top of screen (above spawn_x)
	global_position = Vector2(spawn_x, floor_y - 600.0 if start_y == -9999.0 else start_y)
	_state = NeedleState.WARNING
	_active = true


func _physics_process(delta: float) -> void:
	if not _active:
		return
	match _state:
		NeedleState.WARNING:
			_timer += delta
			# Pulse the warning line alpha
			_warn_line_alpha = 0.35 + sin(_timer * 8.0) * 0.3
			if _warn_line != null:
				_warn_line.modulate.a = _warn_line_alpha
			if _timer >= _warn_time:
				_begin_fall()
		NeedleState.FALLING:
			global_position.y += _fall_speed * delta
			if global_position.y >= _target_y:
				global_position.y = _target_y
				_begin_linger()
		NeedleState.LINGERING:
			_timer += delta
			if _timer >= _linger_time:
				_destroy()
		NeedleState.DONE:
			pass
	super._physics_process(delta)
	queue_redraw()


func _begin_fall() -> void:
	_state = NeedleState.FALLING
	if _warn_line != null:
		_warn_line.hide()
	if _sprite != null:
		_sprite.visible = true
	monitoring = true
	# Teleport to above target
	global_position.y = _target_y - 800.0


func _begin_linger() -> void:
	_state = NeedleState.LINGERING
	_timer = 0.0
	# Keep hitbox active during linger but disable immediately after
	# (handled by _destroy calling queue_free)


func _draw() -> void:
	if _sprite == null or _sprite.texture == null:
		if _state == NeedleState.FALLING or _state == NeedleState.LINGERING:
			draw_rect(Rect2(-8, -30, 16, 60), Color(0.2, 0.0, 0.4, 0.9))


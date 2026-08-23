class_name CrownlandSwordProjectile
extends CrownlandProjectileBase
## 魔剑横扫 / Magic Sword Horizontal Sweep
## A fast horizontal sword body followed by a slower sword-qi wave.
## flip_h = true to go left→right vs right→left.
## Textures: 魔剑右向.png / 右向剑气.png

@export var sword_texture: Texture2D
@export var qi_texture: Texture2D
@export var is_qi: bool = false   # false = sword body, true = sword qi

var _velocity: Vector2 = Vector2.ZERO

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
	_apply_texture()

	if _shape == null:
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(60, 18) if not is_qi else Vector2(48, 14)
		cs.shape = rect
		add_child(cs)
		_shape = cs

	_init_base(0)


func _apply_texture() -> void:
	if _sprite == null:
		return
	_sprite.texture = qi_texture if is_qi else sword_texture


func _draw() -> void:
	if (is_qi and qi_texture == null) or (not is_qi and sword_texture == null):
		var col := Color(0.8, 0.2, 0.0, 0.9) if not is_qi else Color(0.6, 0.3, 0.1, 0.7)
		draw_rect(Rect2(-30, -9, 60, 18), col)


## Launch horizontally. direction: Vector2 (normalised).
## speed: px/sec, damage: int, going_left: sets flip_h.
func launch(direction: Vector2, speed: float, damage: int) -> void:
	_damage = damage
	_velocity = direction.normalized() * speed
	if _sprite != null:
		_sprite.flip_h = direction.x < 0.0
	_active = true


func _physics_process(delta: float) -> void:
	if not _active:
		return
	global_position += _velocity * delta
	super._physics_process(delta)
	queue_redraw()


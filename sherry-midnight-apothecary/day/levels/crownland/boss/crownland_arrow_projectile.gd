class_name CrownlandArrowProjectile
extends CrownlandProjectileBase
## 冠矢弹幕 / Crown Arrow Projectile
## Used in Attack A (fan spray) and Stage 3 black_crown_fan attack.
## Visual: res://day/levels/crownland/boss/半扇展开箭矢.png

## Arrow texture — assign in Inspector or via script before launch().
@export var arrow_texture: Texture2D

var _velocity: Vector2 = Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1   # player physics layer — adjust to project value
	monitoring = true
	monitorable = false

	# Build sprite
	if _sprite == null:
		var s := Sprite2D.new()
		s.name = "Sprite2D"
		add_child(s)
		_sprite = s
	if arrow_texture != null:
		_sprite.texture = arrow_texture
	else:
		# Placeholder: small drawn rectangle
		pass

	# Build collision
	if _shape == null:
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(24, 8)
		cs.shape = rect
		add_child(cs)
		_shape = cs

	_init_base(0)  # damage set by launch()


func _draw() -> void:
	if arrow_texture == null:
		# Placeholder cyan arrow
		draw_rect(Rect2(-12, -4, 24, 8), Color(0.2, 0.1, 0.7, 0.9))


## dir: normalized Vector2, speed: pixels/sec, damage: int
func launch(dir: Vector2, speed: float, damage: int) -> void:
	_damage = damage
	_velocity = dir.normalized() * speed
	rotation = _velocity.angle()
	_active = true


func _physics_process(delta: float) -> void:
	if not _active:
		return
	global_position += _velocity * delta
	super._physics_process(delta)
	queue_redraw()


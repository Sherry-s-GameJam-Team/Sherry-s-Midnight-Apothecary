class_name HelionClockHandSweep
extends Node2D

signal sweep_finished

var _sweep_area: Area2D
var _sweep_collision: CollisionShape2D
var _warning_line: Line2D
var _damage: int = 0
var _has_hit_player: bool = false
var _direction: int = 1
var _tween: Tween

func _ready() -> void:
	_warning_line = Line2D.new()
	_warning_line.width = 10.0
	_warning_line.default_color = Color(1.0, 0.5, 0.0, 0.5)
	_warning_line.hide()
	add_child(_warning_line)
	
	_sweep_area = Area2D.new()
	_sweep_area.collision_layer = 0
	_sweep_area.collision_mask = 2 # Assuming player is on layer 2, adjust if necessary, or just check groups
	add_child(_sweep_area)
	
	_sweep_collision = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, 300)
	_sweep_collision.shape = rect
	_sweep_collision.disabled = true
	_sweep_area.add_child(_sweep_collision)
	
	_sweep_area.body_entered.connect(_on_body_entered)

func begin_sweep(direction: int, damage: int) -> void:
	_direction = direction
	_damage = damage
	_has_hit_player = false
	show_warning()

func show_warning() -> void:
	_warning_line.clear_points()
	_warning_line.add_point(Vector2.ZERO)
	_warning_line.add_point(Vector2(0, 300)) # Pointing towards the ground
	_warning_line.show()

func activate_hitbox() -> void:
	_warning_line.hide()
	_sweep_collision.disabled = false
	
	var start_x = -600.0 if _direction == 1 else 600.0
	var end_x = 600.0 if _direction == 1 else -600.0
	
	_sweep_area.position = Vector2(start_x, 0)
	
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_sweep_area, "position:x", end_x, 0.8)
	_tween.finished.connect(_on_sweep_tween_finished)

func _on_sweep_tween_finished() -> void:
	deactivate_hitbox()
	finish()

func deactivate_hitbox() -> void:
	_sweep_collision.disabled = true

func finish() -> void:
	_warning_line.hide()
	deactivate_hitbox()
	sweep_finished.emit()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _has_hit_player:
		_has_hit_player = true
		_apply_damage(body)

func _apply_damage(player: Node2D) -> void:
	var current = get_parent()
	while current != null:
		if current.has_method("apply_fall_or_hazard_damage"):
			current.apply_fall_or_hazard_damage(_damage, "helion_sweep")
			return
		elif current.has_method("apply_player_damage"):
			current.apply_player_damage(_damage, self)
			return
		current = current.get_parent()

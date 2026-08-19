extends Node2D
class_name HelionClockMarkDrop

var _damage: int = 1
var is_landed: bool = false
var warning_alpha: float = 0.5
var drop_y_start: float = 0.0
var drop_y_end: float = 0.0

var area: Area2D
var shape: CollisionShape2D
var rect_visual: ColorRect

func _ready():
	area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	add_child(area)
	
	shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(60, 60)
	shape.shape = rect_shape
	shape.disabled = true
	area.add_child(shape)
	
	area.body_entered.connect(_on_body_entered)
	
	rect_visual = ColorRect.new()
	rect_visual.color = Color(0.8, 0.2, 0.2, 1.0)
	rect_visual.size = Vector2(60, 60)
	rect_visual.position = Vector2(-30, -30)
	rect_visual.visible = false
	add_child(rect_visual)

func spawn(target_pos: Vector2, damage: int, warning_time: float = 1.0):
	_damage = damage
	global_position = target_pos
	drop_y_end = target_pos.y
	drop_y_start = target_pos.y - 300.0
	
	var warn_tween = create_tween().set_loops()
	warn_tween.tween_property(self, "warning_alpha", 0.9, 0.2)
	warn_tween.tween_property(self, "warning_alpha", 0.3, 0.2)
	
	var drop_timer = get_tree().create_timer(warning_time)
	drop_timer.timeout.connect(_on_warning_done)

func _process(_delta):
	if not is_landed:
		queue_redraw()

func _draw():
	if not is_landed:
		draw_arc(Vector2.ZERO, 30, 0, TAU, 16, Color(1.0, 0.5, 0.0, warning_alpha), 3.0)

func _on_warning_done():
	rect_visual.visible = true
	global_position.y = drop_y_start
	
	var drop_tween = create_tween()
	drop_tween.tween_property(self, "global_position:y", drop_y_end, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	drop_tween.tween_callback(_on_landed)

func _on_landed():
	is_landed = true
	queue_redraw()
	
	shape.disabled = false
	
	var timer = get_tree().create_timer(0.3)
	timer.timeout.connect(_on_hitbox_expired)

func _on_hitbox_expired():
	shape.disabled = true
	
	var fade_tween = create_tween()
	fade_tween.tween_property(rect_visual, "modulate:a", 0.0, 0.2)
	fade_tween.tween_callback(queue_free)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player") or body.name == "Player":
		apply_damage(body)

func apply_damage(_body: Node2D):
	var node = self
	while node:
		if node.has_method("apply_player_damage"):
			node.apply_player_damage(_damage, self)
			return
		elif node.has_method("apply_fall_or_hazard_damage"):
			node.apply_fall_or_hazard_damage(_damage, self)
			return
		node = node.get_parent()

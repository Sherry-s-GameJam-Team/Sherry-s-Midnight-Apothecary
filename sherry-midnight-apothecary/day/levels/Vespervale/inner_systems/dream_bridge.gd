class_name DreamBridge
extends StaticBody2D

## Ethereal platform that solidifies during Dream state and dissolves in Reality.
## Enables upper path connectivity in Section 3 and other zones.

@export var bridge_width: float = 240.0
@export var bridge_thickness: float = 16.0
@export var glow_color: Color = Color(0.75, 0.4, 1.0, 0.85)

var _is_dream: bool = false

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	_update_shape()
	var manager := _find_shift_manager()
	if manager != null:
		manager.dream_state_changed.connect(_on_dream_state_changed)
		_set_active(manager.is_in_dream(), false)
	else:
		_set_active(false, false)


func _update_shape() -> void:
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		add_child(collision_shape)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(bridge_width, bridge_thickness)
	collision_shape.shape = rect
	# Set as one-way or solid platform on layer 1 & 2
	collision_layer = 1 | 2
	collision_mask = 0


func _on_dream_state_changed(in_dream: bool) -> void:
	_set_active(in_dream, true)


func _set_active(active: bool, animate: bool) -> void:
	_is_dream = active
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not active)

	if animate:
		var target_alpha := 1.0 if active else 0.15
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", target_alpha, 0.35)
	else:
		modulate.a = 1.0 if active else 0.15

	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-bridge_width * 0.5, -bridge_thickness * 0.5, bridge_width, bridge_thickness)
	# Glow outline
	draw_rect(rect.grow(4.0), Color(glow_color.r, glow_color.g, glow_color.b, 0.25), false, 2.0)
	# Main luminous bar
	draw_rect(rect, glow_color, true)
	# Ethereal patterned runes/lines
	var step := 24.0
	var count := int(bridge_width / step)
	for i in range(count):
		var x := -bridge_width * 0.5 + float(i) * step + 12.0
		draw_line(Vector2(x, -bridge_thickness * 0.5 + 3.0), Vector2(x, bridge_thickness * 0.5 - 3.0), Color(1.0, 1.0, 1.0, 0.7), 2.0)


func _find_shift_manager() -> DreamShiftManager:
	var cur: Node = self
	while cur != null:
		var mgr := cur.get_node_or_null("DreamShiftManager") as DreamShiftManager
		if mgr != null:
			return mgr
		cur = cur.get_parent()
	return null

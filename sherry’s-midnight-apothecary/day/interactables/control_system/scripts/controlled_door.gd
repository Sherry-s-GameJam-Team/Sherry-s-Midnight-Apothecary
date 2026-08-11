class_name ControlledDoor
extends ControlledBase

## 受控门：激活时向上/向目标偏移滑开并禁用碰撞，未激活时关闭并启用碰撞。

@export var open_offset := Vector2(0, -120)
@export var transition_duration := 0.4

@onready var _visual: Polygon2D = $Visual
@onready var _collision: StaticBody2D = $StaticBody2D
@onready var _collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D
@onready var _closed_position := position


func _on_state_changed(active: bool) -> void:
	var target := _closed_position + open_offset if active else _closed_position
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", active)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target, transition_duration)


func _update_visual(active: bool) -> void:
	if _visual == null:
		return
	_visual.color = active_color if active else inactive_color

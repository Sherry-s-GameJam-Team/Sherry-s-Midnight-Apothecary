class_name ControlledBridge
extends ControlledBase

## 受控桥/平台：激活时变为实心并启用碰撞，未激活时半透明并禁用碰撞，用于提前提示玩家路线。

@export var transition_duration := 0.3
@export var inactive_alpha := 0.4

@onready var _visual: Polygon2D = $Visual
@onready var _collision_shape: CollisionShape2D = $StaticBody2D/CollisionShape2D


func _ready() -> void:
	super()
	if _collision_shape != null:
		_collision_shape.disabled = not _last_effective_state


func _on_state_changed(active: bool) -> void:
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", not active)
	if _visual == null:
		return
	var target_alpha := 1.0 if active else inactive_alpha
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_visual, "color:a", target_alpha, transition_duration)


func _update_visual(active: bool) -> void:
	if _visual == null:
		return
	_visual.color.a = 1.0 if active else inactive_alpha

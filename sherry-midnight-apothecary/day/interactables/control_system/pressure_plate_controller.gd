class_name PressurePlateController
extends ControllerBase

## 压力板：当足够数量的 CharacterBody2D（默认玩家）站在板上时保持激活，离开后恢复未激活。
## 过滤掉 StaticBody2D 等地形，避免场景加载时因地面重叠而直接激活。

@export var activation_layer := 1
@export var require_bodies := 1

@onready var _area: Area2D = $Area2D
@onready var _visual: Polygon2D = $Visual

var _bodies_on_plate := 0


func _ready() -> void:
	super()
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_area.collision_mask = activation_layer
	_update_visual()


func _on_body_entered(body: Node2D) -> void:
	if not _is_valid_body(body):
		return
	_bodies_on_plate += 1
	if _bodies_on_plate >= require_bodies:
		set_active(true)


func _on_body_exited(body: Node2D) -> void:
	if not _is_valid_body(body):
		return
	_bodies_on_plate = maxi(0, _bodies_on_plate - 1)
	if _bodies_on_plate < require_bodies:
		set_active(false)


func _is_valid_body(body: Node2D) -> bool:
	return body is CharacterBody2D


func _update_visual() -> void:
	if _visual == null:
		return
	_visual.color = active_color if is_active else inactive_color
	var depressed := -6.0 if is_active else 0.0
	_visual.position.y = depressed

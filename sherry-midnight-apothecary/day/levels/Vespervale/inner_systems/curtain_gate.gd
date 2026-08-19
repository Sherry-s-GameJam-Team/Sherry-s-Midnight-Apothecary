class_name CurtainGate
extends StaticBody2D

## Fabric curtain barrier that blocks passage until opened by a switch or event.

signal gate_opened
signal gate_closed

@export var is_open: bool = false
@export var open_offset_y: float = -140.0

var _closed_y: float = 0.0

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var curtain_sprite: Sprite2D = get_node_or_null("CurtainSprite")


func _ready() -> void:
	_closed_y = position.y
	if is_open:
		_set_open_instant()


func open() -> void:
	if is_open:
		return
	is_open = true
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", _closed_y + open_offset_y, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.3, 0.6)
	gate_opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", _closed_y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 1.0, 0.5)
	gate_closed.emit()


func _set_open_instant() -> void:
	if collision_shape != null:
		collision_shape.disabled = true
	position.y = _closed_y + open_offset_y
	modulate.a = 0.3

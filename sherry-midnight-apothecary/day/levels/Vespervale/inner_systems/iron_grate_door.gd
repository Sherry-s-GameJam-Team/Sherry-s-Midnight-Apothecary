class_name IronGrateDoor
extends StaticBody2D

## Iron grating barrier that blocks upper platforms until operated by a switch or target.

signal door_opened
signal door_closed

@export var is_open: bool = false
@export var open_offset_y: float = -120.0

var _closed_y: float = 0.0

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var grate_sprite: Sprite2D = get_node_or_null("GrateSprite")


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
	tw.tween_property(self, "modulate:a", 0.35, 0.6)
	door_opened.emit()


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
	door_closed.emit()


func _set_open_instant() -> void:
	if collision_shape != null:
		collision_shape.disabled = true
	position.y = _closed_y + open_offset_y
	modulate.a = 0.35

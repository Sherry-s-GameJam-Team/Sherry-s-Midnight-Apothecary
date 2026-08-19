class_name WardExitDoor
extends StaticBody2D

## Iron ward exit gate. Opens when the Dream Marrow Node is activated.

signal door_opened

@export var is_open: bool = false

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var door_sprite: Sprite2D = get_node_or_null("DoorSprite")


func _ready() -> void:
	if is_open:
		_set_open_instant()


func unlock() -> void:
	if is_open:
		return
	is_open = true
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position:y", position.y - 120.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.3, 0.8)
	door_opened.emit()


func _set_open_instant() -> void:
	if collision_shape != null:
		collision_shape.disabled = true
	position.y -= 120.0
	modulate.a = 0.3

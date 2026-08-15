class_name ForestCorruptedMud
extends StaticBody2D

signal purified

@export var required_potion_id: StringName = &"purification_potion"
var is_purified := false

@onready var visual: CanvasItem = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

func receive_potion_hit(hit: Dictionary) -> void:
	if is_purified:
		return
	var potion_id := StringName(hit.get("potion_id", &""))
	if potion_id == required_potion_id:
		purify()

func purify() -> void:
	if is_purified:
		return
	is_purified = true
	collision.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.35)
	await tween.finished
	visible = false
	purified.emit()

func restore_purified() -> void:
	is_purified = true
	visible = false
	collision.disabled = true

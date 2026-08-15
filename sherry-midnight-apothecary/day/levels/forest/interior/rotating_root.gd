class_name ForestRotatingRoot
extends AnimatableBody2D

signal rotation_slot_changed(slot: int)

@export var angle_slots: Array[float] = [0.0, 90.0, 180.0]
@export var duration := 0.55
var current_slot := 0
var _moving := false

func rotate_to_next() -> void:
	if _moving or angle_slots.is_empty():
		return
	current_slot = (current_slot + 1) % angle_slots.size()
	_moving = true
	var tween := create_tween()
	tween.tween_property(self, "rotation_degrees", angle_slots[current_slot], duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_moving = false
	rotation_slot_changed.emit(current_slot)

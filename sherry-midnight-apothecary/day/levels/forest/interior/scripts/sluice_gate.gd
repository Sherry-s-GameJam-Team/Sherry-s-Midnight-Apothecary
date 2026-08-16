class_name ForestSluiceGate
extends AnimatableBody2D

@export var open_offset := Vector2(0.0, -260.0)
@export var open_time := 0.65

var _closed_position := Vector2.ZERO
var _open := false
var _moving := false


func _ready() -> void:
	_closed_position = position


func open_gate(instant := false) -> void:
	_set_open(true, instant)


func close_gate(instant := false) -> void:
	_set_open(false, instant)


func _set_open(value: bool, instant: bool) -> void:
	if _moving and not instant:
		return
	_open = value
	var target := _closed_position + (open_offset if value else Vector2.ZERO)
	if instant:
		position = target
		_moving = false
		return
	_moving = true
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target, open_time)
	await tween.finished
	_moving = false

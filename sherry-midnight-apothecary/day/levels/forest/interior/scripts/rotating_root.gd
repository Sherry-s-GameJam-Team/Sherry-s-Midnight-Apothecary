class_name ForestRotatingRoot
extends AnimatableBody2D

@export var vertical_degrees := 90.0
@export var horizontal_degrees := 0.0
@export var rotate_time := 0.75
@export var starts_horizontal := false

var _horizontal := false
var _moving := false


func _ready() -> void:
	_horizontal = starts_horizontal
	rotation_degrees = horizontal_degrees if starts_horizontal else vertical_degrees


func set_horizontal(instant := false) -> void:
	_set_rotation_state(true, instant)


func set_vertical(instant := false) -> void:
	_set_rotation_state(false, instant)


func toggle_state() -> void:
	_set_rotation_state(not _horizontal, false)


func _set_rotation_state(horizontal: bool, instant: bool) -> void:
	if _moving and not instant:
		return
	_horizontal = horizontal
	var target := horizontal_degrees if horizontal else vertical_degrees
	if instant:
		rotation_degrees = target
		_moving = false
		return
	_moving = true
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation_degrees", target, rotate_time)
	await tween.finished
	_moving = false

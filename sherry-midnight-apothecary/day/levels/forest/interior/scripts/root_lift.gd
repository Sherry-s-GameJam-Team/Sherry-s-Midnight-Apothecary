class_name ForestRootLift
extends AnimatableBody2D

@export var travel := Vector2(0.0, -330.0)
@export var travel_time := 0.75
@export var starts_high := false

var _low_position := Vector2.ZERO
var _high := false
var _moving := false


func _ready() -> void:
	sync_to_physics = false
	_low_position = position
	_high = starts_high
	if starts_high:
		position = _low_position + travel


func toggle_state() -> void:
	if _moving:
		return
	set_high(not _high)


var _tween: Tween = null


func set_high(value: bool, instant := false) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_high = value
	var target := _low_position + (travel if value else Vector2.ZERO)
	if instant:
		position = target
		_moving = false
		return
	_moving = true
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position", target, travel_time)
	await _tween.finished
	_moving = false


func is_high() -> bool:
	return _high

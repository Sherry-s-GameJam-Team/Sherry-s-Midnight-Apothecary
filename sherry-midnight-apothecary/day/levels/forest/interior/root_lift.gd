class_name ForestRootLift
extends AnimatableBody2D

signal moved(raised: bool)

@export var travel := Vector2(0.0, -360.0)
@export var duration := 0.8
var raised := false
var _origin := Vector2.ZERO
var _moving := false

func _ready() -> void:
	_origin = position

func toggle_lift() -> void:
	set_raised(not raised)

func set_raised(value: bool) -> void:
	if _moving or raised == value:
		return
	_moving = true
	raised = value
	var target := _origin + travel if raised else _origin
	var tween := create_tween()
	tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_moving = false
	moved.emit(raised)

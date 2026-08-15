class_name ForestSluiceGate
extends StaticBody2D

signal state_changed(opened: bool)

@export var open_offset := Vector2(0.0, -180.0)
@export var duration := 0.5
var opened := false
var _origin := Vector2.ZERO

func _ready() -> void:
	_origin = position

func toggle_gate() -> void:
	set_opened(not opened)

func set_opened(value: bool) -> void:
	if opened == value:
		return
	opened = value
	$CollisionShape2D.set_deferred("disabled", opened)
	var target := _origin + open_offset if opened else _origin
	var tween := create_tween()
	tween.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	state_changed.emit(opened)

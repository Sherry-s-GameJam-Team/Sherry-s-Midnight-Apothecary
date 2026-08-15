class_name ForestDirectLift
extends Area2D

signal luca_lift_requested(body: Node2D)

var unlocked := false
var _nearby: Node2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if not unlocked or _nearby == null:
		return
	if (InputMap.has_action(&"interact") and event.is_action_pressed(&"interact")) or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		luca_lift_requested.emit(_nearby)
		get_viewport().set_input_as_handled()

func set_unlocked(value: bool) -> void:
	unlocked = value
	modulate = Color.WHITE if unlocked else Color(0.55, 0.55, 0.55, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Luca" or body.is_in_group("luca"):
		_nearby = body

func _on_body_exited(body: Node2D) -> void:
	if body == _nearby:
		_nearby = null

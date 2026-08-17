class_name ForestControlSwitch
extends Area2D

signal activated(control_id: StringName)

@export var control_id: StringName
@export var target_path: NodePath
@export var target_method: StringName
@export var one_shot := true
var _nearby_luca: Node2D
var _used := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _unhandled_input(event: InputEvent) -> void:
	if _nearby_luca == null or (_used and one_shot):
		return
	if (InputMap.has_action(&"interact") and event.is_action_pressed(&"interact")) or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		_use_switch()

func _use_switch() -> void:
	if target_path != NodePath("") and target_method != &"":
		var target := get_node_or_null(target_path)
		if target != null and target.has_method(target_method):
			target.call(target_method)
	_used = true
	activated.emit(control_id)
	modulate = Color(0.65, 1.0, 0.85, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Luca" or body.is_in_group("luca"):
		_nearby_luca = body

func _on_body_exited(body: Node2D) -> void:
	if body == _nearby_luca:
		_nearby_luca = null

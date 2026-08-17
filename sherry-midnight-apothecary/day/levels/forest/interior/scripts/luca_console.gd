class_name ForestLucaConsole
extends Area2D

@export var action_id: StringName
@export var one_shot := false
@export var operator_name: StringName = &"Luca"
@export var prompt_text := "[E] 操作机关"

@onready var prompt: Label = $Prompt

var _operator_inside := false
var _used := false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false


func _process(_delta: float) -> void:
	var inside := false
	for body in get_overlapping_bodies():
		if _matches_operator(body):
			inside = true
			break
	_operator_inside = inside

	prompt.text = prompt_text
	prompt.visible = _operator_inside and _is_operator_active() and not (_used and one_shot)


func _unhandled_input(event: InputEvent) -> void:
	if _used and one_shot:
		return
	if not _operator_inside or not _is_operator_active():
		return
	if _is_interact_event(event):
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		var level := _get_level()
		if level != null and level.has_method("activate_luca_console"):
			if level.call("activate_luca_console", action_id):
				if one_shot:
					_used = true
					modulate = Color(0.65, 0.95, 0.8, 0.75)
					prompt.visible = false


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if InputMap.has_action(&"interact") and event.is_action_pressed(&"interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)


func _on_body_entered(body: Node2D) -> void:
	if _matches_operator(body):
		_operator_inside = true


func _on_body_exited(body: Node2D) -> void:
	if _matches_operator(body):
		_operator_inside = false


func _matches_operator(body: Node2D) -> bool:
	if body == null:
		return false
	if operator_name == &"Player":
		return body.name == "Player" or body.is_in_group("player")
	return body.name == "Luca" or body.is_in_group("forest_luca_runtime") or body.name == "Player" or body.is_in_group("player")


func _is_operator_active() -> bool:
	var level := _get_level()
	if level == null:
		return true
	if level.has_method("is_luca_active"):
		var luca_active: bool = bool(level.call("is_luca_active"))
		if operator_name == &"Player":
			return not luca_active
		return luca_active
	return true


func _get_level() -> Node:
	var cursor: Node = self
	while cursor != null:
		if cursor.has_method("activate_luca_console"):
			return cursor
		cursor = cursor.get_parent()
	if is_inside_tree() and get_tree() != null:
		var grp := get_tree().get_nodes_in_group("forest_interior_level")
		if not grp.is_empty():
			return grp[0]
	return null

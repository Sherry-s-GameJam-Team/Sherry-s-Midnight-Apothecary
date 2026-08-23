class_name ForestLucaConsole
extends Area2D

@export var action_id: StringName
@export var one_shot := false
@export var operator_name: StringName = &"any"
@export var prompt_text := "[E] 操作机关"

@onready var prompt: Label = $Prompt

var _operator_inside := false
var _used := false
var _overlapping_operators: Array[Node2D] = []


func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false


func _process(_delta: float) -> void:
	_sync_operator_presence()
	prompt.text = prompt_text
	prompt.visible = _operator_inside and not (_used and one_shot)


func _input(event: InputEvent) -> void:
	if _used and one_shot:
		return
	if not _is_interact_event(event):
		return
	_sync_operator_presence()
	if not _operator_inside:
		return
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
	_trigger_interaction()


func _unhandled_input(event: InputEvent) -> void:
	if _used and one_shot:
		return
	if not _is_interact_event(event):
		return
	_sync_operator_presence()
	if not _operator_inside:
		return
	var vp := get_viewport()
	if vp != null:
		vp.set_input_as_handled()
	_trigger_interaction()


func _trigger_interaction() -> void:
	var level := _get_level()
	if level != null:
		var activated := false
		if level.has_method("activate_console"):
			activated = bool(level.call("activate_console", action_id))
		elif level.has_method("activate_luca_console"):
			activated = bool(level.call("activate_luca_console", action_id))
		
		if activated:
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.1)
			tw.tween_property(self, "scale", Vector2.ONE, 0.1)
			if one_shot:
				_used = true
				modulate = Color(0.65, 0.95, 0.8, 0.75)
				prompt.visible = false


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_echo():
		return false
	if InputMap.has_action(&"interact") and event.is_action_pressed(&"interact"):
		return true
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		return key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	return false


func _sync_operator_presence() -> void:
	var inside := false
	for body in _overlapping_operators:
		if is_instance_valid(body):
			inside = true
			break
	if not inside:
		for body in get_overlapping_bodies():
			if _matches_operator(body):
				inside = true
				if not _overlapping_operators.has(body):
					_overlapping_operators.append(body)
				break
	_operator_inside = inside


func _on_body_entered(body: Node2D) -> void:
	if _matches_operator(body):
		if not _overlapping_operators.has(body):
			_overlapping_operators.append(body)
		_operator_inside = true
		prompt.visible = not (_used and one_shot)


func _on_body_exited(body: Node2D) -> void:
	_overlapping_operators.erase(body)
	_sync_operator_presence()


func _matches_operator(body: Node2D) -> bool:
	if body == null or not is_instance_valid(body):
		return false
	if body.name == "Player" or body.is_in_group("player") or body is CharacterBody2D:
		return true
	if body.name == "Luca" or body.is_in_group("forest_luca_runtime"):
		return true
	return false


func _is_operator_active() -> bool:
	return true


func _get_level() -> Node:
	var cursor: Node = self
	while cursor != null:
		if cursor.has_method("activate_console") or cursor.has_method("activate_luca_console"):
			return cursor
		cursor = cursor.get_parent()
	if is_inside_tree() and get_tree() != null:
		var grp := get_tree().get_nodes_in_group("forest_interior_level")
		if not grp.is_empty():
			return grp[0]
		var cur_scene := get_tree().current_scene
		if cur_scene != null and (cur_scene.has_method("activate_console") or cur_scene.has_method("activate_luca_console")):
			return cur_scene
	return null


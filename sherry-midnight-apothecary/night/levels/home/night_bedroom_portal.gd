class_name NightBedroomPortal
extends Area2D

@export var interaction_hint_text := "按[E]进入卧室"
@export_node_path("Sprite2D") var visual_path: NodePath

var _visual: Sprite2D
var _outline_material: Material
var _player_inside := false


func _ready() -> void:
	_visual = get_node_or_null(visual_path) as Sprite2D if not visual_path.is_empty() else get_node_or_null("Visual") as Sprite2D
	if _visual == null:
		push_error("NightBedroomPortal requires a Sprite2D visual.")
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_outline_material = _visual.material
	_visual.material = null


func _input(event: InputEvent) -> void:
	if not _player_inside or not _is_interact_event(event):
		return
	get_viewport().set_input_as_handled()
	_hide_hint()
	var home := _find_night_home()
	if home != null:
		home.request_bedroom()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_player_inside = true
		_visual.material = _outline_material
		_show_hint()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_player_inside = false
		_visual.material = null
		_hide_hint()


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)


func _find_night_home() -> Node:
	# Duck-typed: avoids compile-time class cycle with NightHome.
	var current := get_parent()
	while current != null:
		if current.has_method("request_bedroom"):
			return current
		current = current.get_parent()
	return null


func _show_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_hint_id(), interaction_hint_text)


func _hide_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_hint_id())


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	return null


func _hint_id() -> String:
	return "night_bedroom_portal_%s" % get_instance_id()

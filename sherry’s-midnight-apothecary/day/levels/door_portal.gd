class_name DoorPortal
extends Area2D

## A two-way level doorway. Its Area2D collision is the interaction trigger.

@export var destination_level: StringName
@export var destination_entry_id: StringName = &"default"
@export_file("*.tscn") var fallback_scene_path := ""
@export_node_path("Sprite2D") var visual_path: NodePath

var visual: Sprite2D
var _outline_material: Material
var _player_is_inside := false


func _ready() -> void:
	visual = get_node_or_null(visual_path) as Sprite2D if not visual_path.is_empty() else get_node_or_null("Visual") as Sprite2D
	if visual == null:
		push_error("DoorPortal requires a Sprite2D visual.")
		return
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_outline_material = visual.material
	_set_active(false)


func _input(event: InputEvent) -> void:
	if not _player_is_inside or not _is_interact_event(event):
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()
	var runtime := _find_day_runtime()
	if runtime != null:
		runtime.switch_to_level(str(destination_level), destination_entry_id)
	elif not fallback_scene_path.is_empty():
		get_tree().change_scene_to_file(fallback_scene_path)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_player_is_inside = true
		_set_active(true)


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		_player_is_inside = false
		_set_active(false)


func _is_interact_event(event: InputEvent) -> bool:
	if event.is_action_pressed("interact"):
		return true
	var key_event := event as InputEventKey
	return key_event != null and key_event.pressed and not key_event.echo and (
		key_event.keycode == KEY_E or key_event.physical_keycode == KEY_E
	)


func _set_active(active: bool) -> void:
	if visual != null:
		visual.material = _outline_material if active else null


func _find_day_runtime() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("switch_to_level"):
			return current
		current = current.get_parent()
	return null

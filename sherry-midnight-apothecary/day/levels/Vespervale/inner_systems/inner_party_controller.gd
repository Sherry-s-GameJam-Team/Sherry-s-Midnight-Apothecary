class_name InnerPartyController
extends Node2D

## Dual-character party controller for Vespervale Inner Ward Corridor.
## Handles C-key character switching between Sherry (lower) and Luca (upper).
## Manages camera tracking, input routing, and active-character highlighting.

signal active_character_changed(character_id: StringName)

@export var sherry_path: NodePath = NodePath("../Player")
@export var luca_path: NodePath = NodePath("../Luca")
@export var camera_path: NodePath = NodePath("../Player/Camera2D")
@export var switching_enabled: bool = true

var active_character: StringName = &"sherry"

@onready var sherry: Node2D = get_node_or_null(sherry_path)
@onready var luca: Node2D = get_node_or_null(luca_path)
@onready var camera: Camera2D = get_node_or_null(camera_path)


func _ready() -> void:
	# Ensure camera is found even if paths differ
	if camera == null and sherry != null:
		camera = sherry.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS

	_update_character_states()


func enable_switching(enabled: bool) -> void:
	switching_enabled = enabled


func restore_sherry_control() -> void:
	active_character = &"sherry"
	_update_character_states()


func _unhandled_input(event: InputEvent) -> void:
	if not switching_enabled:
		return

	var requested := false
	if InputMap.has_action(&"switch_character") and event.is_action_pressed(&"switch_character"):
		requested = true
	elif InputMap.has_action(&"switch_protagonist") and event.is_action_pressed(&"switch_protagonist"):
		requested = true
	elif event is InputEventKey and event.pressed and not event.echo:
		requested = (
			event.keycode == KEY_C or event.physical_keycode == KEY_C
			or event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB
		)

	if requested:
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		set_active_character(&"luca" if active_character == &"sherry" else &"sherry")


func set_active_character(character_id: StringName) -> void:
	if character_id == active_character:
		return
	active_character = character_id
	_update_character_states()
	active_character_changed.emit(active_character)


func _update_character_states() -> void:
	var is_sherry := (active_character == &"sherry")

	# Update Sherry
	if sherry != null:
		_set_body_control(sherry, is_sherry)
		_set_body_highlight(sherry, is_sherry)

	# Update Luca
	if luca != null:
		_set_body_control(luca, not is_sherry)
		_set_body_highlight(luca, not is_sherry)

	# Update Camera tracking
	var target := sherry if is_sherry else luca
	if camera != null and target != null:
		if camera.get_parent() != target:
			camera.reparent(target, false)
			camera.position = Vector2(0, -80)
			camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS


func is_character_active(body: Node) -> bool:
	if body == null:
		return true
	if active_character == &"sherry":
		return body == sherry or body.name == "Player"
	else:
		return body == luca or body.name == "Luca"


func active_body() -> Node2D:
	return sherry if active_character == &"sherry" else luca


func _set_body_control(body: Node, enabled: bool) -> void:
	if body.has_method("set_control_enabled"):
		body.call("set_control_enabled", enabled)
	elif body.has_method("set_dialogue_locked"):
		body.call("set_dialogue_locked", not enabled)
	elif body is CharacterBody2D:
		body.set_physics_process(true) # Keep gravity and collision active for safe physics


func _set_body_highlight(body: Node2D, active: bool) -> void:
	if body == null:
		return
	var target_modulate := Color(1.0, 1.0, 1.0, 1.0) if active else Color(0.75, 0.75, 0.85, 0.85)
	var tw := create_tween()
	tw.tween_property(body, "modulate", target_modulate, 0.2)

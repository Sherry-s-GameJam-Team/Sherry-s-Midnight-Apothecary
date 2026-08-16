class_name ForestPartyController
extends Node

signal active_character_changed(character_id: StringName)

@export var sherry_path: NodePath
@export var luca_path: NodePath
@export var camera_path: NodePath
@export var luca_world_controller_path: NodePath

var active_character: StringName = &"sherry"
var switching_enabled := false

@onready var sherry: Node2D = get_node(sherry_path)
@onready var luca: Node2D = get_node(luca_path)
@onready var camera: Camera2D = get_node(camera_path)
@onready var luca_world_controller: Node = get_node_or_null(luca_world_controller_path)

func _ready() -> void:
	_set_control(sherry, true)
	_set_control(luca, false)
	_set_luca_view(false)

func enable_switching(enabled: bool) -> void:
	switching_enabled = enabled
	if not enabled and active_character != &"sherry":
		set_active_character(&"sherry")

func _unhandled_input(event: InputEvent) -> void:
	if not switching_enabled:
		return
	var requested := false
	if InputMap.has_action(&"switch_character"):
		requested = event.is_action_pressed(&"switch_character")
	elif event is InputEventKey:
		requested = event.pressed and not event.echo and event.keycode == KEY_TAB
	if requested:
		set_active_character(&"luca" if active_character == &"sherry" else &"sherry")
		get_viewport().set_input_as_handled()

func set_active_character(character_id: StringName) -> void:
	if character_id == active_character:
		return
	var target: Node2D = luca if character_id == &"luca" else sherry
	var previous: Node2D = sherry if active_character == &"sherry" else luca
	_set_control(previous, false)
	_set_control(target, true)
	camera.reparent(target, true)
	camera.position = Vector2.ZERO
	active_character = character_id
	_set_luca_view(active_character == &"luca")
	active_character_changed.emit(active_character)

func active_body() -> Node2D:
	return luca if active_character == &"luca" else sherry

func _set_luca_view(enabled: bool) -> void:
	if luca_world_controller != null and luca_world_controller.has_method("set_luca_view"):
		luca_world_controller.call("set_luca_view", enabled)

func _set_control(body: Node, enabled: bool) -> void:
	if body.has_method("set_control_enabled"):
		body.call("set_control_enabled", enabled)
	elif body.has_method("set_dialogue_locked"):
		body.call("set_dialogue_locked", not enabled)

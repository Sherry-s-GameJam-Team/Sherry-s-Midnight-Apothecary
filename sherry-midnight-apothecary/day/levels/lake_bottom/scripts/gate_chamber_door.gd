class_name GateChamberDoor
extends Area2D

@export var destination_level: StringName = &"lake_bottom"
@export var destination_entry_id: StringName = &"maintenance"
@export_file("*.tscn") var fallback_scene_path: String = "res://day/levels/lake_bottom/lake.tscn"
@export var prompt_text: String = "E 返回阿里特之泪湖床"
@export var player_group: StringName = &"player"
@export var requires_activation := false

var _player_near := false
var _portal_active := true

@onready var prompt: Label = get_node_or_null("Prompt")
@onready var glow: PointLight2D = get_node_or_null("Glow")

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_portal_active = not requires_activation
	if prompt:
		prompt.text = prompt_text
	_set_portal_active(_portal_active)

func set_portal_active(value: bool) -> void:
	_set_portal_active(value)

func _set_portal_active(value: bool) -> void:
	_portal_active = value
	visible = value
	monitoring = value
	monitorable = value
	if prompt:
		prompt.visible = value and _player_near
	if glow:
		glow.energy = 0.6 if value else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not _portal_active or not _player_near:
		return
	if event.is_action_pressed(&"interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		_travel()

func _travel() -> void:
	var runtime := _find_day_runtime()
	if runtime != null:
		runtime.switch_to_level(str(destination_level), destination_entry_id)
	elif not fallback_scene_path.is_empty():
		get_tree().change_scene_to_file(fallback_scene_path)

func _on_enter(body: Node) -> void:
	if body.is_in_group(player_group) or body is CharacterBody2D:
		_player_near = true
		if _portal_active and prompt:
			prompt.visible = true
		if _portal_active and glow:
			create_tween().tween_property(glow, "energy", 1.8, 0.3)

func _on_exit(body: Node) -> void:
	if body.is_in_group(player_group) or body is CharacterBody2D:
		_player_near = false
		if prompt:
			prompt.visible = false
		if glow:
			create_tween().tween_property(glow, "energy", 0.5, 0.3)

func _find_day_runtime() -> Node:
	var current: Node = self
	while current != null:
		if current.has_method("switch_to_level"):
			return current
		current = current.get_parent()
	return null

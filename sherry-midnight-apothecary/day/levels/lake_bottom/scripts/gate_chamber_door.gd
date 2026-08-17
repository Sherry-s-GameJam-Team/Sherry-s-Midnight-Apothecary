class_name GateChamberDoor
extends Area2D

@export var destination_level: StringName = &"lake_bottom"
@export var destination_entry_id: StringName = &"maintenance"
@export_file("*.tscn") var fallback_scene_path: String = "res://day/levels/lake_bottom/lake.tscn"
@export var prompt_text: String = "E 返回阿里特之泪湖床"
@export var player_group: StringName = &"player"

var _player_near := false

@onready var prompt: Label = get_node_or_null("Prompt")
@onready var glow: PointLight2D = get_node_or_null("Glow")

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	if prompt:
		prompt.visible = false
		prompt.text = prompt_text

func _unhandled_input(event: InputEvent) -> void:
	if not _player_near:
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
		if prompt:
			prompt.visible = true
		if glow:
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

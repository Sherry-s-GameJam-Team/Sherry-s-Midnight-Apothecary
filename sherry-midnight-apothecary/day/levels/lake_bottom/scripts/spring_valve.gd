extends Area2D

@export var valve_id: StringName = &"valve_01"
@export var interaction_action: StringName = &"interact"
@export var player_group: StringName = &"player"

var _player_near := false
var _activated := false

@onready var sprite: Sprite2D = get_node_or_null("Sprite")
@onready var prompt: Label = get_node_or_null("Prompt")
@onready var glow: PointLight2D = get_node_or_null("Glow")

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	if prompt:
		prompt.visible = false
	if glow:
		glow.energy = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if _activated or not _player_near:
		return
	if event.is_action_pressed(interaction_action):
		var vp := get_viewport()
		if vp != null:
			vp.set_input_as_handled()
		activate()

func activate() -> void:
	if _activated:
		return
	_activated = true
	if prompt:
		prompt.visible = false
	var tween := create_tween().set_parallel(true)
	if sprite:
		tween.tween_property(sprite, "rotation", sprite.rotation + TAU, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(sprite, "modulate", Color(0.65, 1.0, 1.0, 1.0), 0.4)
	if glow:
		tween.tween_property(glow, "energy", 1.7, 0.5)
	var level := _find_level()
	if level and level.has_method("on_spring_valve_activated"):
		level.on_spring_valve_activated(valve_id)


func set_interaction_enabled(enabled: bool) -> void:
	monitoring = enabled
	monitorable = enabled
	_player_near = false
	if prompt:
		prompt.visible = false

func _on_enter(body: Node) -> void:
	if body.is_in_group(player_group) or body is CharacterBody2D:
		_player_near = true
		if prompt and not _activated:
			prompt.visible = true

func _on_exit(body: Node) -> void:
	if body.is_in_group(player_group) or body is CharacterBody2D:
		_player_near = false
		if prompt:
			prompt.visible = false

func _find_level() -> Node:
	var n: Node = self
	while n:
		if n.has_method("on_spring_valve_activated"):
			return n
		n = n.get_parent()
	return null

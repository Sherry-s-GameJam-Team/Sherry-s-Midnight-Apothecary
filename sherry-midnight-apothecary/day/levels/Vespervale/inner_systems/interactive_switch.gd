class_name InteractiveSwitch
extends Area2D

## Interactive mechanism switch for Luca (or Sherry) to operate treatment boards, cabinets, and consoles.
## Unlocks gates, disables bullet launchers, or slows obstacles.

signal activated
signal deactivated

@export var prompt_text: String = "按 E 操作机关"
@export var is_one_shot: bool = true
@export var active_duration: float = 0.0 # 0.0 means permanent until toggled
@export var target_nodes: Array[NodePath] = []
@export var target_method_on_activate: String = "open"

var is_activated: bool = false
var _player_in_range: bool = false
var _timer: float = 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var indicator_light: Sprite2D = get_node_or_null("IndicatorLight")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_visuals()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range:
		return
	if is_one_shot and is_activated:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		toggle_switch()


func _process(delta: float) -> void:
	if is_activated and active_duration > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			deactivate_switch()


func toggle_switch() -> void:
	if not is_activated:
		activate_switch()
	elif not is_one_shot:
		deactivate_switch()


func activate_switch() -> void:
	is_activated = true
	if active_duration > 0.0:
		_timer = active_duration
	activated.emit()
	_invoke_targets(target_method_on_activate)
	_update_visuals()
	_update_hint()


func deactivate_switch() -> void:
	is_activated = false
	deactivated.emit()
	_invoke_targets("close")
	_update_visuals()
	_update_hint()


func _invoke_targets(method_name: String) -> void:
	for path in target_nodes:
		var target := get_node_or_null(path)
		if target != null and target.has_method(method_name):
			target.call(method_name)


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and (body.is_in_group("player") or body.name == "Player" or body.name == "Luca"):
		_player_in_range = true
		_update_hint()


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D and (body.is_in_group("player") or body.name == "Player" or body.name == "Luca"):
		_player_in_range = false
		_update_hint()


func _update_hint() -> void:
	var can_act := _player_in_range and (not is_activated or not is_one_shot)
	var top_hint := _find_top_hint()
	if top_hint != null:
		if can_act:
			if top_hint.has_method("show_interaction_hint"):
				top_hint.call("show_interaction_hint", String(name), prompt_text)
		else:
			if top_hint.has_method("hide_interaction_hint"):
				top_hint.call("hide_interaction_hint", String(name))


func _update_visuals() -> void:
	if indicator_light != null:
		indicator_light.modulate = Color(0.3, 1.0, 0.5, 1.0) if is_activated else Color(0.8, 0.4, 0.4, 0.6)
	if sprite != null:
		var target_color := Color(1.1, 1.1, 1.2, 1.0) if is_activated else Color(0.9, 0.9, 0.9, 1.0)
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", target_color, 0.2)


func _find_top_hint() -> Node:
	var cur: Node = self
	while cur != null:
		var hint := cur.get_node_or_null("PauseMenuLayer/TopHintUI")
		if hint == null:
			hint = cur.get_node_or_null("TopHintUI")
		if hint != null:
			return hint
		cur = cur.get_parent()
	return null

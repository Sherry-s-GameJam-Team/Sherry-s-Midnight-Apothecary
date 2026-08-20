class_name HelionTriggerGear
extends Area2D
## Interactive gear pedestal on Floor 6 to initiate the Helion Boss battle.
## Player approaches and presses E (interact) or hits with a potion to start.

signal activated

@export var rotation_speed: float = 30.0  # Idle rotation deg/s

var _is_triggered: bool = false
var _player_in_range: bool = false

@onready var gear_sprite: Sprite2D = get_node_or_null("GearSprite")


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if not _is_triggered and gear_sprite != null:
		gear_sprite.rotation_degrees += rotation_speed * delta


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and not _is_triggered and event.is_action_pressed("interact"):
		activate()
		get_viewport().set_input_as_handled()


func activate() -> void:
	if _is_triggered:
		return
	_is_triggered = true
	_player_in_range = false

	var top_hint := _find_top_hint()
	if top_hint != null and top_hint.has_method("hide_interaction_hint"):
		top_hint.call("hide_interaction_hint", _hint_id())

	# Spin rapidly and fade down into the pedestal
	if gear_sprite != null:
		var tween := create_tween()
		if tween != null:
			tween.tween_property(gear_sprite, "rotation_degrees", gear_sprite.rotation_degrees + 720.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(gear_sprite, "scale", Vector2.ZERO, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.finished.connect(func() -> void:
				visible = false
			)

	# Sound
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var audio: Node = tree.get_first_node_in_group("clocktower_audio")
			if audio != null and audio.has_method("play_gear_clack"):
				audio.call("play_gear_clack")

	activated.emit()

	# Notify arena directly
	var arena: Node = get_parent()
	while arena != null:
		if arena.has_method("trigger_boss_battle"):
			var player := _find_player()
			arena.call("trigger_boss_battle", player)
			break
		arena = arena.get_parent()


func receive_potion_hit(_hit: Dictionary) -> void:
	activate()


func _on_body_entered(body: Node2D) -> void:
	if _is_triggered:
		return
	if body.is_in_group("player") or body.name == "Player" or body is CharacterBody2D:
		_player_in_range = true
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("show_interaction_hint"):
			top_hint.call("show_interaction_hint", _hint_id(), "按 E 启动守时圣像·赫利昂")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player" or body is CharacterBody2D:
		_player_in_range = false
		var top_hint := _find_top_hint()
		if top_hint != null and top_hint.has_method("hide_interaction_hint"):
			top_hint.call("hide_interaction_hint", _hint_id())


func _hint_id() -> String:
	return "helion_trigger_gear"


func _find_player() -> Node2D:
	if is_inside_tree() and get_tree() != null:
		return get_tree().get_first_node_in_group("player") as Node2D
	return null


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null and top_hint.is_node_ready():
			return top_hint
		current = current.get_parent()
	if is_inside_tree() and get_tree() != null and get_tree().root != null:
		return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	return null
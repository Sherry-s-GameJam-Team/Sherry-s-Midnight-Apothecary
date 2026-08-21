class_name SewerHydraulicInteractable
extends Sprite2D

## Attached directly to an editor-visible puzzle sprite. This handles only
## proximity/input; SewerHydraulicGatePuzzle remains the local state owner.
@export var puzzle_path: NodePath
@export var valve := 0
@export var interact_action: StringName = &"interact"
@export var hint_panel_path: NodePath
@export var rotate_on_interact := false
@export var rotate_target_path: NodePath

@onready var _puzzle := get_node_or_null(puzzle_path) as SewerHydraulicGatePuzzle
@onready var _hint_panel := get_node_or_null(hint_panel_path) as CanvasItem
@onready var _rotate_target := get_node_or_null(rotate_target_path) as Node2D
@onready var _interaction_area := get_node_or_null("InteractionArea") as Area2D

var _turn_tween: Tween
var _player_inside := false


func _ready() -> void:
	if _interaction_area != null:
		_interaction_area.body_entered.connect(_on_body_entered)
		_interaction_area.body_exited.connect(_on_body_exited)
	_update_hint_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(interact_action) and _player_inside and _puzzle != null:
		if _puzzle.try_interact(valve):
			if rotate_on_interact:
				_play_turn_animation()
			get_viewport().set_input_as_handled()


func _update_hint_visibility() -> void:
	if _hint_panel != null:
		_hint_panel.visible = _player_inside


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_inside = true
		_update_hint_visibility()


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_inside = false
		_update_hint_visibility()


func _is_player(body: Node2D) -> bool:
	return body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player"))


func _play_turn_animation() -> void:
	if _turn_tween != null and _turn_tween.is_valid():
		_turn_tween.kill()
	var target: Node2D = _rotate_target if _rotate_target != null else self
	_turn_tween = create_tween()
	_turn_tween.tween_property(target, "rotation", target.rotation + TAU, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

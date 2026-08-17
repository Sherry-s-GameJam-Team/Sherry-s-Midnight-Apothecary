class_name HintArea
extends Node2D

## 靠近提示区域：挂载在其他节点下方，玩家进入 Area2D 时通过顶部 TopHintUI 显示提示文本。

@export var hint_text := ""
@export var hint_id := ""
@export var detection_layer := 1

@onready var _area: Area2D = $Area2D

var _resolved_hint_id: String = ""


func _ready() -> void:
	_resolved_hint_id = hint_id if not hint_id.is_empty() else "hint_area_%s" % get_instance_id()
	if _area == null:
		push_error("HintArea requires an Area2D child named 'Area2D'.")
		return
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	_area.collision_layer = 0
	_area.collision_mask = detection_layer


func _exit_tree() -> void:
	_hide_hint()


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_show_hint()


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_hide_hint()


func _is_player(body: Node2D) -> bool:
	return body is CharacterBody2D and (body.name == "Player" or body.is_in_group("player"))


func _show_hint() -> void:
	if hint_text.is_empty():
		return
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.show_interaction_hint(_resolved_hint_id, hint_text)


func _hide_hint() -> void:
	var top_hint := _find_top_hint()
	if top_hint != null:
		top_hint.hide_interaction_hint(_resolved_hint_id)


func _find_top_hint() -> TopHintUI:
	var current: Node = self
	while current != null:
		var top_hint := current.get_node_or_null("GlobalUI/TopHintUI") as TopHintUI
		if top_hint != null:
			return top_hint
		current = current.get_parent()
	if is_inside_tree() and get_tree() != null:
		return get_tree().root.find_child("TopHintUI", true, false) as TopHintUI
	return null

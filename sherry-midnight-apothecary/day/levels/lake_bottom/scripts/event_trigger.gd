extends Area2D

@export var event_id: StringName = &"event"
@export var one_shot := true
@export var player_group: StringName = &"player"
var _fired := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _fired and one_shot:
		return
	if not (body.is_in_group(player_group) or body is CharacterBody2D):
		return
	_fired = true
	var level := _find_level()
	if event_id == &"dashiyu_found" and level and level.has_method("on_dashiyu_found"):
		level.on_dashiyu_found()
	elif level and level.has_method("_emit_world_event"):
		level._emit_world_event(event_id, {})

func _find_level() -> Node:
	var n: Node = self
	while n:
		if n.has_method("on_level_entered"):
			return n
		n = n.get_parent()
	return null

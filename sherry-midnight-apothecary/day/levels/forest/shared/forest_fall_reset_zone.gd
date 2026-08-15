class_name ForestFallResetZone
extends Area2D

@export var damage := 1
@export var reason: StringName = &"forest_fall"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("forest_character") or body.is_in_group("player") or body.name == "Player" or body.name == "Luca":
		var forest := _find_forest()
		if forest != null and forest.has_method("request_respawn"):
			forest.call("request_respawn", body, reason, damage)

func _find_forest() -> Node:
	var cursor: Node = get_parent()
	while cursor != null:
		if cursor.has_method("request_respawn") and cursor.has_method("set_corrupted"):
			return cursor
		cursor = cursor.get_parent()
	return null

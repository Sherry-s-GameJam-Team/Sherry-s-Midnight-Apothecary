extends Area2D

@export var sherry_respawn_path: NodePath
@export var luca_anchor_path: NodePath
@export var max_luca_vertical_gap := 850.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	var level := _get_level()
	if level == null:
		return
	if body.name == "Player" or body.is_in_group("player"):
		var sherry_marker := level.get_node_or_null(sherry_respawn_path) as Marker2D
		if sherry_marker != null:
			level.register_respawn(body, sherry_marker)
		var luca := level.get_node_or_null("Luca") as CharacterBody2D
		var luca_anchor := level.get_node_or_null(luca_anchor_path) as Marker2D
		if luca != null and luca_anchor != null and luca.global_position.y > luca_anchor.global_position.y + max_luca_vertical_gap:
			luca.velocity = Vector2.ZERO
			luca.global_position = luca_anchor.global_position
			level.register_respawn(luca, luca_anchor)
	elif body.name == "Luca" or body.is_in_group("forest_luca_runtime"):
		var luca_anchor := level.get_node_or_null(luca_anchor_path) as Marker2D
		if luca_anchor != null:
			level.register_respawn(body, luca_anchor)

func _get_level() -> ForestInteriorLevel:
	var cursor: Node = self
	while cursor != null:
		if cursor is ForestInteriorLevel:
			return cursor as ForestInteriorLevel
		cursor = cursor.get_parent()
	return null

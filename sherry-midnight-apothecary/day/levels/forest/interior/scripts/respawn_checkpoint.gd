extends Area2D

@export var marker_path: NodePath


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player" and body.name != "Luca" and not body.is_in_group("player"):
		return
	var level := _get_level()
	if level == null:
		return
	var marker := level.get_node_or_null(marker_path) as Marker2D
	if marker != null:
		level.register_respawn(body, marker)


func _get_level() -> ForestInteriorLevel:
	var cursor: Node = self
	while cursor != null:
		if cursor is ForestInteriorLevel:
			return cursor as ForestInteriorLevel
		cursor = cursor.get_parent()
	return null

extends Area2D

@export_range(0, 100, 1) var damage := 10


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player" and body.name != "Luca" and not body.is_in_group("player"):
		return
	var level := _get_level()
	if level != null:
		level.request_respawn(body, "forest_interior_fall", damage)


func _get_level() -> ForestInteriorLevel:
	var cursor: Node = self
	while cursor != null:
		if cursor is ForestInteriorLevel:
			return cursor as ForestInteriorLevel
		cursor = cursor.get_parent()
	return null

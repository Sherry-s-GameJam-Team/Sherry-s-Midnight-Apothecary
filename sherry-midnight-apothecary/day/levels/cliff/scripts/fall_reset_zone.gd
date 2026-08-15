extends Area2D

@export_range(0, 100, 1) var damage := 15


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var level := get_tree().get_first_node_in_group("cliff_level")
	if level != null and level.has_method("request_respawn"):
		level.call("request_respawn", body, "fall", damage)

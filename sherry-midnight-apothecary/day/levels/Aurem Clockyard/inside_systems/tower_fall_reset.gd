class_name TowerFallResetZone
extends Area2D

@export var floor_id: int = 1
@export var damage: int = 5


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		var level := get_tree().get_first_node_in_group("clocktower_inside")
		if level != null and level.has_method("request_fall_respawn"):
			level.call("request_fall_respawn", body, floor_id, damage)

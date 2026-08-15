class_name ForestBossTrigger
extends Area2D

@export var boss_interface_path: NodePath
var triggered := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if triggered or not (body.is_in_group("player") or body.is_in_group("forest_character") or body.name == "Player"):
		return
	triggered = true
	var boss := get_node_or_null(boss_interface_path)
	if boss != null and boss.has_method("begin_boss"):
		boss.call("begin_boss")

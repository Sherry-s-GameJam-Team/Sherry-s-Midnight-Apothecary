class_name PillarShelter
extends StaticBody2D

## High structural pillar / partition that absorbs dream bullets and provides safe cover.

@export var shelter_width: float = 60.0
@export var shelter_height: float = 380.0

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	add_to_group("pillar_shelter")
	collision_layer = 1 | 2
	collision_mask = 0
	if collision_shape != null and collision_shape.shape is RectangleShape2D:
		(collision_shape.shape as RectangleShape2D).size = Vector2(shelter_width, shelter_height)

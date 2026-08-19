class_name DreamBedSafeZone
extends Area2D

## Safe zone attached to Dream Hospital Beds.
## When the active player stands in this area:
## - Dream Grasp Hands cease tracking and enter Lurk state.
## - Active hunting timer resets to 0.
## - A soft, ethereal lunar-white/light-purple elliptical ward aura glows around the bed.

signal player_entered_bed(body: Node2D)
signal player_exited_bed(body: Node2D)

var _sheltered_bodies: Array[Node2D] = []

@onready var aura_node: Node2D = get_node_or_null("SafeZoneAura")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	add_to_group("bed_safe_zone")
	collision_layer = 0
	collision_mask = 1 | 2 # Detect Player and Luca
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_aura_visuals()


func _on_body_entered(body: Node2D) -> void:
	if not _sheltered_bodies.has(body):
		_sheltered_bodies.append(body)
		player_entered_bed.emit(body)
		_update_aura_visuals()


func _on_body_exited(body: Node2D) -> void:
	if _sheltered_bodies.has(body):
		_sheltered_bodies.erase(body)
		player_exited_bed.emit(body)
		_update_aura_visuals()


func is_body_sheltered(body: Node2D) -> bool:
	return _sheltered_bodies.has(body)


func has_any_sheltered_player() -> bool:
	return not _sheltered_bodies.is_empty()


func _update_aura_visuals() -> void:
	if aura_node != null:
		var target_alpha := 0.7 if has_any_sheltered_player() else 0.28
		var tw := create_tween()
		tw.tween_property(aura_node, "modulate:a", target_alpha, 0.3)

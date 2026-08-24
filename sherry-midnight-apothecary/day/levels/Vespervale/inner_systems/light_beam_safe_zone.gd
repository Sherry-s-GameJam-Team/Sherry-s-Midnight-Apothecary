class_name LightBeamSafeZone
extends Area2D

## Downward projected holy light cone / sanctuary zone from the upper floor.
## Provides safe sanctuary against Dream Grasp Hands when active.
## Can be turned on/off by upper PressurePlates.

signal beam_activated
signal beam_deactivated

@export var is_active: bool = false
@export var beam_width: float = 180.0
@export var beam_height: float = 240.0

var _sheltered_bodies: Array[Node2D] = []

@onready var light_sprite: Sprite2D = get_node_or_null("BeamSprite")
@onready var aura_node: Node2D = get_node_or_null("BeamAura")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")


func _ready() -> void:
	add_to_group("bed_safe_zone")
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_state(is_active, true)


func activate() -> void:
	open()


func deactivate() -> void:
	close()


func open() -> void:
	if is_active:
		return
	is_active = true
	_update_state(true)
	beam_activated.emit()


func close() -> void:
	if not is_active:
		return
	is_active = false
	_update_state(false)
	beam_deactivated.emit()


func is_body_sheltered(body: Node2D) -> bool:
	if not is_active:
		return false
	return _sheltered_bodies.has(body)


func _on_body_entered(body: Node2D) -> void:
	if not _sheltered_bodies.has(body):
		_sheltered_bodies.append(body)


func _on_body_exited(body: Node2D) -> void:
	if _sheltered_bodies.has(body):
		_sheltered_bodies.erase(body)


func _update_state(active: bool, instant: bool = false) -> void:
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not active)

	var target_alpha := 0.75 if active else 0.0
	if instant:
		modulate.a = target_alpha
		visible = active
	else:
		visible = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", target_alpha, 0.3)
		if not active:
			tw.tween_callback(func() -> void:
				if not is_active:
					visible = false
			)

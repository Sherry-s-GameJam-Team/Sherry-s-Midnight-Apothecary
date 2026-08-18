class_name PlayerHitboxCore
extends Node2D

## Phase 3 STG-style precision hitbox core indicator displayed on Sherry's center point.

@export var is_active: bool = false
@export var core_radius: float = 24.0

var _anim_time: float = 0.0

@onready var core_sprite: Sprite2D = get_node_or_null("CoreSprite")
@onready var ring_node: Node2D = get_node_or_null("Ring")
@onready var ring_line: Line2D = get_node_or_null("Ring/RingLine")
@onready var hurtbox_area: Area2D = get_node_or_null("HurtboxArea")


func _ready() -> void:
	z_index = 25
	visible = false
	modulate.a = 0.0
	add_to_group("player_hitbox_core")
	if hurtbox_area != null:
		hurtbox_area.monitoring = false
		hurtbox_area.monitorable = false


func activate() -> void:
	is_active = true
	visible = true
	if hurtbox_area != null:
		hurtbox_area.monitoring = true
		hurtbox_area.monitorable = true
	var tw := create_tween()
	scale = Vector2(0.3, 0.3)
	tw.parallel().tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func deactivate() -> void:
	is_active = false
	if hurtbox_area != null:
		hurtbox_area.monitoring = false
		hurtbox_area.monitorable = false
	var tw := create_tween()
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "scale", Vector2(0.4, 0.4), 0.2)
	tw.tween_callback(func() -> void: visible = false)


func receive_hit(damage: float, knockback: Vector2 = Vector2.ZERO) -> void:
	var parent := get_parent()
	if parent != null:
		if parent.has_method("receive_hit"):
			parent.call("receive_hit", damage, knockback)
		elif parent.has_method("play_hazard_hit"):
			parent.call("play_hazard_hit", knockback)


func _process(delta: float) -> void:
	if not is_active and modulate.a <= 0.0:
		return

	_anim_time += delta
	# Rotate outer ring and pulse inner core
	if ring_node != null:
		ring_node.rotation += delta * 2.8

	var pulse := 1.0 + sin(_anim_time * 8.0) * 0.12
	if ring_line != null:
		ring_line.scale = Vector2(pulse, pulse)

	if core_sprite != null:
		var core_pulse := 1.0 + cos(_anim_time * 10.0) * 0.18
		core_sprite.scale = Vector2(0.35 * core_pulse, 0.35 * core_pulse)

class_name BeatTelegraphLight
extends Node2D

@onready var light_sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var glow_circle: Sprite2D = get_node_or_null("GlowCircle")

var _is_stable: bool = false


func _ready() -> void:
	_update_glow(0.3, Color(1.0, 0.6, 0.1))


func set_stable(stable: bool) -> void:
	_is_stable = stable
	if _is_stable:
		_update_glow(0.8, Color(1.0, 0.9, 0.3))


func flash_signal(is_anomaly: bool) -> void:
	if _is_stable:
		return
	if is_anomaly:
		# Double flash
		var tween := create_tween()
		tween.tween_method(_set_glow_alpha, 0.2, 1.2, 0.12)
		tween.tween_method(_set_glow_alpha, 1.2, 0.2, 0.12)
		tween.tween_method(_set_glow_alpha, 0.2, 1.2, 0.12)
		tween.tween_method(_set_glow_alpha, 1.2, 0.3, 0.2)
	else:
		# Single flash
		var tween := create_tween()
		tween.tween_method(_set_glow_alpha, 0.2, 1.0, 0.2)
		tween.tween_method(_set_glow_alpha, 1.0, 0.3, 0.3)


func _set_glow_alpha(alpha: float) -> void:
	if glow_circle != null:
		glow_circle.modulate.a = alpha


func _update_glow(alpha: float, color: Color) -> void:
	if glow_circle != null:
		glow_circle.modulate = color
		glow_circle.modulate.a = alpha

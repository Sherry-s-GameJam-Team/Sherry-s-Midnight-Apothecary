extends Area2D

@export var cooldown := 1.0

var _cooling := false

@onready var marker: Marker2D = get_node_or_null("WaterTarget")
@onready var splash: Node2D = get_node_or_null("WaterSplash")

func _ready() -> void:
	if splash:
		splash.visible = false

## PotionProjectile direct hit handler
func receive_potion_hit(hit: Dictionary) -> void:
	var point: Vector2 = hit.get("impact_point", marker.global_position if marker else global_position)
	_trigger_splash_and_bait(point)

## PotionEffectExecutor splash effect handler
func apply_potion_effect(_effect_id: StringName, context: Dictionary) -> void:
	var point: Vector2 = context.get("impact_point", marker.global_position if marker else global_position)
	_trigger_splash_and_bait(point)

func _trigger_splash_and_bait(point: Vector2) -> void:
	if _cooling:
		return
	_play_splash(point)
	var level := _find_level()
	if level and level.has_method("try_bait_with_potion"):
		level.try_bait_with_potion(point)
	elif level and level.has_method("try_use_springburst"):
		level.try_use_springburst(point)
	_cooling = true
	await get_tree().create_timer(cooldown).timeout
	_cooling = false

func _play_splash(at_point: Vector2 = Vector2.ZERO) -> void:
	if splash == null:
		return
	if at_point != Vector2.ZERO:
		splash.global_position = at_point
	splash.visible = true
	splash.scale = Vector2(0.2, 0.2)
	splash.modulate.a = 1.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(splash, "scale", Vector2(1.0, 2.8), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(splash, "modulate:a", 0.0, 0.8).set_delay(0.35)
	await tween.finished
	splash.visible = false

func _find_level() -> Node:
	var n: Node = self
	while n:
		if n.has_method("try_bait_with_potion") or n.has_method("try_use_springburst"):
			return n
		n = n.get_parent()
	return null


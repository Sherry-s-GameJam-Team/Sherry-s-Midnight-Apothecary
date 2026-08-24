class_name ForestCorruptedMud
extends StaticBody2D

signal purified
signal water_progress_changed(progress: float)

var is_purified := false
var water_progress := 0.0
@export var water_required_seconds := 0.8

@onready var visual: CanvasItem = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D

func receive_potion_hit(hit: Dictionary) -> void:
	if is_purified:
		return
	if PotionCapabilityResolver.hit_has_capability(hit, &"purify_strong"):
		purify()

func purify() -> void:
	if is_purified:
		return
	is_purified = true
	collision.set_deferred("disabled", true)
	var tween := create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.35)
	await tween.finished
	visible = false
	purified.emit()

func receive_water(delta: float) -> void:
	if is_purified:
		return
	water_progress = minf(water_required_seconds, water_progress + delta)
	water_progress_changed.emit(water_progress)
	if water_progress >= water_required_seconds:
		purify()

func restore_purified() -> void:
	is_purified = true
	visible = false
	collision.disabled = true

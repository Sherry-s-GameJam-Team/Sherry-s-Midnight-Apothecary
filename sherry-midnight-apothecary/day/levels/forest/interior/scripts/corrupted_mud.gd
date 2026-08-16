class_name ForestInteriorCorruptedMud
extends StaticBody2D

@export var water_seconds_to_cleanse := 0.8

@onready var visual: Polygon2D = $Visual
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var bubbles: CPUParticles2D = $Bubbles

var _water_progress := 0.0
var _purified := false
var _environment_corrupted := true


func _ready() -> void:
	add_to_group("forest_mud")


func receive_potion_hit(hit: Dictionary) -> void:
	if _purified:
		return
	if StringName(hit.get("potion_id", &"")) == &"purification_potion":
		purify()


func receive_water_jet(delta: float) -> void:
	if _purified or not _environment_corrupted:
		return
	_water_progress = minf(water_seconds_to_cleanse, _water_progress + delta)
	if visual.material is ShaderMaterial:
		(visual.material as ShaderMaterial).set_shader_parameter("cleanse_progress", _water_progress / water_seconds_to_cleanse)
	if _water_progress >= water_seconds_to_cleanse:
		purify()


func purify(instant := false) -> void:
	if _purified:
		return
	_purified = true
	collision.set_deferred("disabled", true)
	bubbles.emitting = false
	if instant:
		visible = false
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.tween_property(self, "scale", Vector2(scale.x, scale.y * 0.15), 0.35)
	await tween.finished
	visible = false


func set_environment_corrupted(corrupted: bool) -> void:
	_environment_corrupted = corrupted
	if not corrupted:
		purify(true)

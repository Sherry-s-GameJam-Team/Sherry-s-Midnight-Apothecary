class_name SewerLucaWaterReflection
extends Node2D

## Direct child of the Luca scene instance. This intentionally bypasses the
## shared reflection controller so Luca's water image cannot be lost to a
## sibling layer, visibility gate, or instanced-child override.
@export var waterline_y := 516.0
@export_range(0.05, 1.0, 0.01) var vertical_compression := 0.2
@export var vertical_offset := 20.0
@export_range(1.0, 2.0, 0.01) var horizontal_scale := 1.2

@onready var _luca := get_parent() as LucaPlayer
@onready var _visual := $LucaVisual as Sprite2D


func _process(_delta: float) -> void:
	if _luca == null or _visual == null:
		return
	var frames := _luca.animated_sprite.sprite_frames
	if frames == null or not frames.has_animation(_luca.animated_sprite.animation):
		return

	_visual.texture = frames.get_frame_texture(_luca.animated_sprite.animation, _luca.animated_sprite.frame)
	_visual.flip_h = _luca.animated_sprite.flip_h
	var mirrored_depth := (waterline_y - _luca.global_position.y) * vertical_compression
	global_position = Vector2(_luca.global_position.x, waterline_y + mirrored_depth + vertical_offset)
	scale = Vector2(horizontal_scale, -vertical_compression)
	visible = _luca.visible

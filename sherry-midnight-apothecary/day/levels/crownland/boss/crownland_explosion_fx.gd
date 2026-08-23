class_name CrownlandExplosionFx
extends Node2D
## 爆破帧动画 / Explosion Frame Animation
## Plays 爆破帧1.png → 爆破帧2.png → 爆破帧3.png → 爆破帧4.png then queue_free().
## Visual only — damage is dealt by a separate Area2D spawned by BattleDirector.

@export var frame_textures: Array[Texture2D] = []  ## [帧1, 帧2, 帧3, 帧4]
@export var fps: float = 12.0
@export var scale_factor: float = 1.0

var _frame_index: int = 0
var _timer: float = 0.0
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite2D"
	_sprite.scale = Vector2.ONE * scale_factor
	add_child(_sprite)
	_show_frame(0)


func _process(delta: float) -> void:
	if frame_textures.is_empty():
		queue_free()
		return
	_timer += delta
	var frame_time := 1.0 / maxf(fps, 1.0)
	while _timer >= frame_time:
		_timer -= frame_time
		_frame_index += 1
		if _frame_index >= frame_textures.size():
			queue_free()
			return
		_show_frame(_frame_index)


func _show_frame(idx: int) -> void:
	if _sprite == null:
		return
	if idx < frame_textures.size() and frame_textures[idx] != null:
		_sprite.texture = frame_textures[idx]
	else:
		# Placeholder: draw coloured circle
		_sprite.texture = null
		queue_redraw()


func _draw() -> void:
	if frame_textures.is_empty() or (
			_frame_index < frame_textures.size() and frame_textures[_frame_index] == null):
		var alpha := 1.0 - float(_frame_index) / maxf(float(frame_textures.size()), 1.0)
		draw_circle(Vector2.ZERO, 40.0 * scale_factor, Color(1.0, 0.5, 0.0, alpha))


func cleanup() -> void:
	queue_free()


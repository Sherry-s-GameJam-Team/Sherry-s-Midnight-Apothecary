extends Node2D

## Moves a pair of aligned cloud canvases and wraps them without a visible seam.
@export var speed := 7.0
@export var loop_width := 3840.0


func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x <= -loop_width:
		position.x += loop_width

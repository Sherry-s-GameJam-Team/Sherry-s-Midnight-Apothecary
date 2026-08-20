extends AnimatedSprite2D

## Keeps the suspended forest NPC moving smoothly from the first frame to the
## last, then back again, without a visible jump at either end of the motion.

@export var hanging_animation: StringName = &"hang"

var _playing_forward := true


func _ready() -> void:
	animation_finished.connect(_reverse_playback)
	play(hanging_animation)


func _reverse_playback() -> void:
	_playing_forward = not _playing_forward
	play(hanging_animation, 1.0 if _playing_forward else -1.0, not _playing_forward)

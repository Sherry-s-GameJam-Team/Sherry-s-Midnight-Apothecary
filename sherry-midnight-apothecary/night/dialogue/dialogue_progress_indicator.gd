class_name DialogueProgressIndicator
extends Sprite2D

@export_range(1, 240, 1) var frame_count := 58
@export_range(1.0, 120.0, 0.1) var frames_per_second := 33.333
@export var playing := true:
	set(value):
		if playing == value:
			return
		playing = value
		_elapsed = 0.0
		frame = 0

var _elapsed := 0.0
var _was_visible := false


func _process(delta: float) -> void:
	var currently_visible := is_visible_in_tree()
	if not playing:
		_elapsed = 0.0
		frame = 0
		_was_visible = currently_visible
		return
	if currently_visible and not _was_visible:
		_elapsed = 0.0
		frame = 0
	if currently_visible:
		_elapsed = fmod(_elapsed + delta, frame_count / frames_per_second)
		frame = mini(int(_elapsed * frames_per_second), frame_count - 1)
	_was_visible = currently_visible


func set_playing(value: bool) -> void:
	playing = value


func is_playing() -> bool:
	return playing

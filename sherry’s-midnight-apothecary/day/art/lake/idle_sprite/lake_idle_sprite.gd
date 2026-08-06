@tool
class_name LakeIdleSprite
extends Node2D

## A 45-frame (12 fps) loop placed in the lake. Its position and scale remain
## editable through this node's Transform section in the Inspector.
@export_group("Animation Preview")
@export_range(1.0, 60.0, 0.5, "suffix: fps") var frames_per_second := 12.0:
	set(value):
		frames_per_second = maxf(value, 1.0)
		if is_node_ready():
			_apply_playback_settings()

@export var preview_playing := true:
	set(value):
		preview_playing = value
		if is_node_ready():
			_apply_playback_settings()

@export var loop := true:
	set(value):
		loop = value
		if is_node_ready():
			_apply_playback_settings()

@export var show_in_editor := true:
	set(value):
		show_in_editor = value
		if is_node_ready():
			idle_loop.visible = show_in_editor

@onready var idle_loop: AnimatedSprite2D = $IdleLoop


func _ready() -> void:
	_apply_playback_settings()


func _process(_delta: float) -> void:
	if preview_playing and is_instance_valid(idle_loop) and not idle_loop.is_playing():
		idle_loop.play(&"idle_loop")


func _apply_playback_settings() -> void:
	if not is_instance_valid(idle_loop):
		return
	idle_loop.visible = show_in_editor
	idle_loop.sprite_frames.set_animation_speed(&"idle_loop", frames_per_second)
	idle_loop.sprite_frames.set_animation_loop(&"idle_loop", loop)
	if preview_playing:
		idle_loop.play(&"idle_loop")
	else:
		idle_loop.pause()

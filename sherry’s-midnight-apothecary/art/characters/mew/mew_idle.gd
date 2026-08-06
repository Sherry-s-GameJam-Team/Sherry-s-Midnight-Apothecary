@tool
class_name MewIdle
extends Node2D

## A 45-frame idle loop (12 fps) + 40-frame fishing animation (8 fps).
## Position and scale remain editable through this node's Transform.
enum Action { IDLE, FISHING }

@export_group("Animation Preview")
@export var action := Action.IDLE:
	set(value):
		action = value
		if is_node_ready():
			_switch_action()

@export_range(1.0, 60.0, 0.5, "suffix: fps") var idle_fps := 12.0:
	set(value):
		idle_fps = maxf(value, 1.0)
		if is_node_ready() and action == Action.IDLE:
			_apply_playback_settings()

@export_range(1.0, 60.0, 0.5, "suffix: fps") var fishing_fps := 8.0:
	set(value):
		fishing_fps = maxf(value, 1.0)
		if is_node_ready() and action == Action.FISHING:
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
			_update_visibility()

@onready var idle_loop: AnimatedSprite2D = $IdleLoop
@onready var fishing_loop: AnimatedSprite2D = $FishingLoop

func _ready() -> void:
	_switch_action()
	_apply_playback_settings()

func _process(_delta: float) -> void:
	var current := _get_active_sprite()
	if preview_playing and is_instance_valid(current) and not current.is_playing():
		current.play(current.animation)

func play_idle() -> void:
	action = Action.IDLE
	_switch_action()

func play_fishing() -> void:
	action = Action.FISHING
	_switch_action()

func _get_active_sprite() -> AnimatedSprite2D:
	return fishing_loop if action == Action.FISHING else idle_loop

func _get_active_animation() -> StringName:
	return &"fishing" if action == Action.FISHING else &"idle_loop"

func _get_active_fps() -> float:
	return fishing_fps if action == Action.FISHING else idle_fps

func _switch_action() -> void:
	if not is_instance_valid(idle_loop) or not is_instance_valid(fishing_loop):
		return
	idle_loop.visible = show_in_editor and action == Action.IDLE
	fishing_loop.visible = show_in_editor and action == Action.FISHING
	idle_loop.pause()
	fishing_loop.pause()
	_apply_playback_settings()

func _update_visibility() -> void:
	if is_instance_valid(idle_loop):
		idle_loop.visible = show_in_editor and action == Action.IDLE
	if is_instance_valid(fishing_loop):
		fishing_loop.visible = show_in_editor and action == Action.FISHING

func _apply_playback_settings() -> void:
	var sprite := _get_active_sprite()
	var anim := _get_active_animation()
	if not is_instance_valid(sprite):
		return
	sprite.visible = show_in_editor
	sprite.sprite_frames.set_animation_speed(anim, _get_active_fps())
	sprite.sprite_frames.set_animation_loop(anim, loop)
	if preview_playing:
		sprite.play(anim)
	else:
		sprite.pause()
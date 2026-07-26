extends Node2D

signal startup_started
signal startup_finished
signal close_started
signal close_finished

const FRAME_DIR := "res://art/raintree/startup_animation/frames"
const STARTUP_ANIMATION := "startup"
const CLOSE_ANIMATION := "close"
const INTERACTION_REMINDER_MANAGER_SCRIPT = preload("res://game/src/system/reminder/interaction_reminder_manager.gd")

@export var interact_distance := 120.0
@export var animation_speed := 12.0
@export var near_modulate := Color(0.58, 0.58, 0.58, 1.0)
@export var default_modulate := Color(1.0, 1.0, 1.0, 1.0)
@export var open_prompt_text := "按下 E 打开入口"
@export var close_prompt_text := "按下 E 关闭入口"

var player: Node2D = null
var interaction_enabled := true
var is_animation_playing := false
var is_prompt_active := false
var is_open := false
var pending_open_state := false
var interaction_reminder_manager: Node = null

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_ensure_startup_frames()
	_set_interaction_feedback(false)
	if sprite != null and not sprite.animation_finished.is_connected(_on_sprite_animation_finished):
		sprite.animation_finished.connect(_on_sprite_animation_finished)


func set_player(player_node: Node) -> void:
	player = player_node as Node2D


func set_interaction_enabled(enabled: bool) -> void:
	interaction_enabled = enabled
	if not interaction_enabled:
		_set_interaction_feedback(false)


func _process(_delta: float) -> void:
	if not interaction_enabled or is_animation_playing:
		_set_interaction_feedback(false)
		return

	_set_interaction_feedback(_is_player_near())


func _unhandled_input(event: InputEvent) -> void:
	if not interaction_enabled or is_animation_playing or not is_prompt_active:
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_E:
			toggle_startup()
			_mark_input_handled()


func toggle_startup() -> void:
	if is_open:
		play_close()
	else:
		play_startup()


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func play_startup() -> void:
	_play_animation(STARTUP_ANIMATION, true)


func play_close() -> void:
	_play_animation(CLOSE_ANIMATION, false)


func _play_animation(animation_name: StringName, target_open_state: bool) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.get_frame_count(animation_name) <= 0:
		return

	is_animation_playing = true
	pending_open_state = target_open_state
	_set_interaction_feedback(false)
	_set_player_input_locked(true)
	if target_open_state:
		startup_started.emit()
	else:
		close_started.emit()

	sprite.stop()
	sprite.animation = animation_name
	sprite.frame = 0
	sprite.play()


func _ensure_startup_frames() -> void:
	if sprite == null:
		return
	if (
		sprite.sprite_frames != null
		and sprite.sprite_frames.get_frame_count(STARTUP_ANIMATION) > 0
		and sprite.sprite_frames.get_frame_count(CLOSE_ANIMATION) > 0
	):
		sprite.animation = STARTUP_ANIMATION
		sprite.frame = 0
		return

	_load_startup_frames()


func _load_startup_frames() -> void:
	if sprite == null:
		return

	var frames := SpriteFrames.new()
	frames.add_animation(STARTUP_ANIMATION)
	frames.set_animation_loop(STARTUP_ANIMATION, false)
	frames.set_animation_speed(STARTUP_ANIMATION, animation_speed)
	frames.add_animation(CLOSE_ANIMATION)
	frames.set_animation_loop(CLOSE_ANIMATION, false)
	frames.set_animation_speed(CLOSE_ANIMATION, animation_speed)

	var sorted_files: PackedStringArray = DirAccess.get_files_at(FRAME_DIR)
	sorted_files.sort()
	for file_name in sorted_files:
		var file_string: String = String(file_name)
		if not file_string.ends_with(".png"):
			continue
		var animation_name := _animation_name_for_frame_file(file_string)
		if animation_name.is_empty():
			continue

		var texture_path: String = FRAME_DIR.path_join(file_string)
		var texture: Texture2D = null
		if ResourceLoader.exists(texture_path, "Texture2D"):
			texture = load(texture_path) as Texture2D
		if texture == null:
			var image := Image.load_from_file(ProjectSettings.globalize_path(texture_path))
			if image != null and not image.is_empty():
				texture = ImageTexture.create_from_image(image)
		if texture != null:
			frames.add_frame(animation_name, texture)

	sprite.sprite_frames = frames
	sprite.animation = STARTUP_ANIMATION
	sprite.frame = 0


func _animation_name_for_frame_file(file_name: String) -> StringName:
	if file_name.begins_with("startup_"):
		return STARTUP_ANIMATION
	if file_name.begins_with("close_"):
		return CLOSE_ANIMATION
	return &""


func _is_player_near() -> bool:
	if player == null:
		return false

	return player.global_position.distance_to(global_position) <= interact_distance


func _set_interaction_feedback(active: bool) -> void:
	is_prompt_active = active
	if sprite != null:
		sprite.self_modulate = near_modulate if active else default_modulate
	_set_interaction_reminder(active)


func _set_interaction_reminder(active: bool) -> void:
	if not is_inside_tree():
		return

	var reminder_manager := _interaction_reminder_manager(active)
	if reminder_manager == null:
		return
	if active:
		reminder_manager.call("show_interaction", self, close_prompt_text if is_open else open_prompt_text)
	else:
		reminder_manager.call("hide_interaction", self)


func _interaction_reminder_manager(create_if_missing: bool = true) -> Node:
	if interaction_reminder_manager != null and is_instance_valid(interaction_reminder_manager):
		return interaction_reminder_manager

	var parent := get_tree().current_scene
	if parent == null:
		parent = get_tree().root

	var existing := parent.get_node_or_null("InteractionReminderManager")
	if existing != null:
		interaction_reminder_manager = existing
		return interaction_reminder_manager
	if not create_if_missing:
		return null

	interaction_reminder_manager = INTERACTION_REMINDER_MANAGER_SCRIPT.new() as Node
	interaction_reminder_manager.name = "InteractionReminderManager"
	parent.add_child(interaction_reminder_manager)
	return interaction_reminder_manager


func _set_player_input_locked(locked: bool) -> void:
	if is_instance_valid(player) and player.has_method("set_input_locked"):
		player.call("set_input_locked", locked)


func _on_sprite_animation_finished() -> void:
	if not is_animation_playing:
		return

	is_animation_playing = false
	is_open = pending_open_state
	_set_player_input_locked(false)
	if is_open:
		startup_finished.emit()
	else:
		close_finished.emit()

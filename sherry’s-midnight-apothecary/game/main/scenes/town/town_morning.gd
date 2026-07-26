extends Node2D

signal changer_transition_requested(from_node: String, to_node: String, from_index: int, to_index: int)
signal interior_exit_to_destination(destination_key: String)
signal interior_transition_progress_changed(destination_key: String, progress: float)

const SLEEP_TRIGGER_SCENE := preload("res://art/shared/interactions/sleep/bed_sleep_trigger/bed_sleep_trigger.tscn")
const TEXTURE_WIDTH := 2170.0
const CLOUD_SCROLL_SPEED := 28.0
const TITLE_INTRO_CAMERA_DURATION := 1.4
const TITLE_SLEEP_FADE_IN_DURATION := 0.18
const TITLE_SLEEP_FADE_OUT_DURATION := 0.32
const TITLE_SLEEP_POSITION := Vector2(-160.0, -82.0)
const TITLE_SLEEP_SCALE := Vector2(0.75, 0.75)
const TITLE_HOME_CAMERA_OFFSET := Vector2(0.0, -120.0)
const TITLE_ROOM_CAMERA_ZOOM_MULTIPLIER := 0.75
const TITLE_AREA_NODE_NAME := "titlearea"
const LAYER_SCROLL_FACTORS := {
	"Distant": 0.30,
	"Middle": 0.55,
	"Near": 0.78,
}

@export var start_in_title_intro := true

var cloud_scroll := 0.0
var camera_anchor := Vector2.ZERO
var skybox_origin := Vector2.ZERO
var clouds_origin := Vector2.ZERO
var layer_origins := {}
var changer_current_node := "home"
var is_title_intro_active := false
var is_title_intro_starting := false
var sleep_sprite: Node2D = null
var sleep_sprite_editor_modulate := Color.WHITE
var title_intro_camera_zoom := Vector2.ONE
var title_intro_player_spawn_position := Vector2.ZERO
var player_was_visible := true

@onready var camera: Camera2D = $Player/Camera2D
@onready var player: CharacterBody2D = $Player
@onready var foreground_mask: Node = $ForegroundMask
@onready var camera_controller: TownCameraController = $TownCameraController
@onready var title_menu: CanvasLayer = get_node_or_null("TitleMenuLayer") as CanvasLayer
@onready var parallax_root: Node2D = $ParallaxLayers
@onready var skybox: Node2D = $ParallaxLayers/Skybox
@onready var clouds: Node2D = $ParallaxLayers/Clouds
@onready var parallax_layers := {
	"Distant": $ParallaxLayers/Distant,
	"Middle": $ParallaxLayers/Middle,
	"Near": $ParallaxLayers/Near,
}


func _ready() -> void:
	parallax_root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera_anchor = camera.get_screen_center_position()
	skybox_origin = skybox.global_position
	clouds_origin = clouds.global_position
	title_intro_player_spawn_position = player.global_position

	for layer_name in parallax_layers:
		layer_origins[layer_name] = (parallax_layers[layer_name] as Node2D).global_position

	if foreground_mask.has_signal("changer_transition_requested"):
		foreground_mask.connect("changer_transition_requested", _on_changer_transition_requested)
	if foreground_mask.has_signal("interior_exit_to_destination"):
		foreground_mask.connect("interior_exit_to_destination", _on_interior_exit_to_destination)
	if foreground_mask.has_signal("interior_transition_progress_changed"):
		foreground_mask.connect("interior_transition_progress_changed", _on_interior_transition_progress_changed)

	if title_menu != null:
		if title_menu.has_signal("start_requested"):
			title_menu.connect("start_requested", play_title_intro_start)
		if title_menu.has_signal("quit_requested"):
			title_menu.connect("quit_requested", _on_title_quit_requested)
		title_menu.visible = start_in_title_intro

	if start_in_title_intro:
		enter_title_intro()
	else:
		camera_controller.enter_outdoor_mode(true)

	_update_parallax_layers()


func _process(delta: float) -> void:
	cloud_scroll = fposmod(cloud_scroll + CLOUD_SCROLL_SPEED * delta, TEXTURE_WIDTH)
	_update_parallax_layers()


func _update_parallax_layers() -> void:
	var camera_delta := camera.get_screen_center_position() - camera_anchor
	var camera_delta_x := Vector2(camera_delta.x, 0.0)

	skybox.global_position = skybox_origin + camera_delta_x
	clouds.global_position = clouds_origin + camera_delta_x + Vector2(-cloud_scroll, 0.0)

	for layer_name in parallax_layers:
		var layer := parallax_layers[layer_name] as Node2D
		var layer_origin: Vector2 = layer_origins[layer_name]
		var scroll_factor := float(LAYER_SCROLL_FACTORS[layer_name])
		layer.global_position = layer_origin + Vector2(camera_delta.x * (1.0 - scroll_factor), 0.0)


func _on_changer_transition_requested(from_node: String, to_node: String, _from_index: int, _to_index: int) -> void:
	changer_current_node = to_node
	changer_transition_requested.emit(from_node, to_node, _from_index, _to_index)
	print("Town changer transition: ", from_node, " -> ", to_node)


func _on_interior_exit_to_destination(destination_key: String) -> void:
	interior_exit_to_destination.emit(destination_key)


func _on_interior_transition_progress_changed(destination_key: String, progress: float) -> void:
	interior_transition_progress_changed.emit(destination_key, progress)


func get_interior_transition_state(destination_key: String) -> Dictionary:
	if foreground_mask != null and foreground_mask.has_method("get_interior_transition_state"):
		var state = foreground_mask.call("get_interior_transition_state", destination_key)
		if state is Dictionary:
			return state as Dictionary
	return {}


func prepare_for_arrival(from_key: String, arrival_state: Dictionary = {}) -> void:
	if foreground_mask != null and foreground_mask.has_method("prepare_for_arrival"):
		foreground_mask.call("prepare_for_arrival", from_key, arrival_state)


func prepare_transition_preview_from(source_scene: Node) -> void:
	hide_title_intro_artifacts()

	if foreground_mask == null or not foreground_mask.has_method("prepare_transition_preview_from"):
		return

	var source_foreground := source_scene.get_node_or_null("ForegroundMask") if source_scene != null else null
	foreground_mask.call("prepare_transition_preview_from", source_foreground)


func enter_title_intro() -> void:
	if is_title_intro_active:
		return

	is_title_intro_active = true
	is_title_intro_starting = false
	player_was_visible = player.visible
	_store_title_intro_camera_state()
	_set_player_input_locked(true)
	player.visible = false

	if foreground_mask != null and foreground_mask.has_method("show_title_room_state"):
		foreground_mask.call("show_title_room_state")

	_create_sleep_sprite()
	var title_camera_center := _title_intro_camera_center()
	camera_controller.enter_title_mode(title_camera_center)
	_update_parallax_layers()


func play_title_intro_start() -> void:
	if not is_title_intro_active or is_title_intro_starting:
		return

	is_title_intro_starting = true
	start_in_title_intro = false
	if title_menu != null and title_menu.has_method("fade_out"):
		title_menu.call("fade_out")

	var target_camera_center := _title_intro_room_entry_center()
	var target_camera_zoom := _title_intro_room_entry_zoom()
	var sleep_animation := _play_sleep_trigger_animation()
	if sleep_sprite != null:
		var sleep_fade_in := create_tween()
		sleep_fade_in.tween_property(
			sleep_sprite,
			"modulate",
			sleep_sprite_editor_modulate,
			TITLE_SLEEP_FADE_IN_DURATION
		)
	await camera_controller.transition_to_target(
		target_camera_center,
		target_camera_zoom,
		TITLE_INTRO_CAMERA_DURATION
	)

	if is_instance_valid(sleep_animation) and sleep_animation.is_playing():
		await sleep_animation.animation_finished

	if is_instance_valid(sleep_sprite):
		var sleep_fade_tween := create_tween()
		sleep_fade_tween.tween_property(
			sleep_sprite,
			"modulate",
			_sleep_sprite_hidden_modulate(),
			TITLE_SLEEP_FADE_OUT_DURATION
		)
		await sleep_fade_tween.finished

	player.global_position = title_intro_player_spawn_position.round()
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()

	if foreground_mask != null and foreground_mask.has_method("finish_title_room_to_inside_state"):
		foreground_mask.call("finish_title_room_to_inside_state", target_camera_center, target_camera_zoom)

	player.visible = player_was_visible
	_set_player_input_locked(false)
	is_title_intro_active = false
	is_title_intro_starting = false
	hide_title_intro_artifacts()
	_update_parallax_layers()


func _store_title_intro_camera_state() -> void:
	title_intro_camera_zoom = camera.zoom


func _create_sleep_sprite() -> void:
	if sleep_sprite != null:
		return

	var sleep_parent := _sleep_sprite_parent()
	if sleep_parent == null:
		push_warning("Could not find title sleep sprite parent.")
		return

	sleep_sprite = _editor_sleep_sprite()
	if sleep_sprite != null:
		var editor_global_transform := sleep_sprite.global_transform
		if sleep_sprite.get_parent() != sleep_parent:
			sleep_sprite.reparent(sleep_parent, false)
			sleep_sprite.global_transform = editor_global_transform
		_prepare_sleep_sprite_for_intro()
		return

	sleep_sprite = SLEEP_TRIGGER_SCENE.instantiate() as Node2D
	if sleep_sprite == null:
		push_warning("Could not instantiate sleep sprite.")
		return

	sleep_sprite.name = "TitleSleepSprite"
	sleep_parent.add_child(sleep_sprite)
	sleep_sprite.position = TITLE_SLEEP_POSITION
	sleep_sprite.scale = TITLE_SLEEP_SCALE
	sleep_sprite.z_index = 18
	_prepare_sleep_sprite_for_intro()


func _prepare_sleep_sprite_for_intro() -> void:
	if sleep_sprite == null:
		return

	sleep_sprite_editor_modulate = sleep_sprite.modulate
	if sleep_sprite_editor_modulate.a <= 0.0:
		sleep_sprite_editor_modulate.a = 1.0
	sleep_sprite.visible = false
	sleep_sprite.modulate = _sleep_sprite_hidden_modulate()
	_freeze_sleep_sprite_first_frame()


func _editor_sleep_sprite() -> Node2D:
	var root_sprite := get_node_or_null("TitleSleepSprite") as Node2D
	if root_sprite != null:
		return root_sprite

	var sleep_parent := _sleep_sprite_parent()
	if sleep_parent == null:
		return null
	return sleep_parent.get_node_or_null("TitleSleepSprite") as Node2D


func _sleep_sprite_hidden_modulate() -> Color:
	return Color(
		sleep_sprite_editor_modulate.r,
		sleep_sprite_editor_modulate.g,
		sleep_sprite_editor_modulate.b,
		0.0
	)


func _sleep_sprite_parent() -> Node2D:
	if foreground_mask == null:
		return null
	return foreground_mask.get_node_or_null("InteriorRoom/HomeInside") as Node2D


func _title_intro_camera_center() -> Vector2:
	var title_area_node := _title_area_node()
	if title_area_node != null:
		return _align_title_center_to_fixed_room_x(_title_area_node_center(title_area_node))

	if foreground_mask != null:
		var home := foreground_mask.get_node_or_null("Home") as Node2D
		if home != null:
			return _align_title_center_to_fixed_room_x(home.global_position + TITLE_HOME_CAMERA_OFFSET)
		var interior_room := foreground_mask.get_node_or_null("InteriorRoom") as Node2D
		if interior_room != null:
			return _align_title_center_to_fixed_room_x(interior_room.global_position + TITLE_HOME_CAMERA_OFFSET)
	if foreground_mask != null:
		var marker := foreground_mask.get_node_or_null("TownInteriorCameraCenter") as Marker2D
		if marker != null:
			return marker.global_position + TITLE_HOME_CAMERA_OFFSET
	return camera.get_screen_center_position()


func _title_area_node() -> Node:
	var node := _find_title_area_node(self)
	if node == null and foreground_mask != null:
		node = _find_title_area_node(foreground_mask)
	return node


func _title_area_node_center(node: Node) -> Vector2:
	var collision := node as CollisionShape2D
	if collision != null:
		return _collision_shape_center(collision)

	var child_collision := node.find_child("CollisionShape2D", true, false) as CollisionShape2D
	if child_collision != null:
		return _collision_shape_center(child_collision)

	var node_2d := node as Node2D
	if node_2d != null:
		return node_2d.global_position
	return camera.get_screen_center_position()


func _find_title_area_node(root: Node) -> Node:
	if root == null:
		return null
	if _normalized_node_name(root.name) == TITLE_AREA_NODE_NAME:
		return root

	for child in root.get_children():
		var found := _find_title_area_node(child)
		if found != null:
			return found
	return null


func _normalized_node_name(node_name: StringName) -> String:
	return String(node_name).to_lower().replace(" ", "").replace("_", "")


func _collision_shape_center(collision: CollisionShape2D) -> Vector2:
	return collision.global_position


func _freeze_sleep_sprite_first_frame() -> void:
	if sleep_sprite == null:
		return

	var animated_sprite := sleep_sprite.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		return

	animated_sprite.stop()
	animated_sprite.frame = 0
	animated_sprite.frame_progress = 0.0


func _play_sleep_trigger_animation() -> AnimatedSprite2D:
	if sleep_sprite == null:
		_create_sleep_sprite()
	if sleep_sprite == null:
		return null

	sleep_sprite.visible = true
	sleep_sprite.modulate = _sleep_sprite_hidden_modulate()

	var animated_sprite := sleep_sprite.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		return null

	animated_sprite.animation = &"awake"
	animated_sprite.frame = 0
	animated_sprite.frame_progress = 0.0
	animated_sprite.play()
	return animated_sprite


func hide_title_intro_artifacts() -> void:
	start_in_title_intro = false
	if is_instance_valid(title_menu):
		title_menu.visible = false

	if is_instance_valid(sleep_sprite):
		_free_node_now(sleep_sprite)
	sleep_sprite = null

	_remove_named_descendants(self, &"TitleMenuLayer")
	_remove_named_descendants(self, &"TitleSleepSprite")


func _remove_named_descendants(root: Node, node_name: StringName) -> void:
	for child in root.get_children():
		if child.name == node_name:
			_free_node_now(child)
		else:
			_remove_named_descendants(child, node_name)


func _free_node_now(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent != null:
		parent.remove_child(node)
	node.free()


func _title_intro_room_entry_center() -> Vector2:
	return _title_intro_fixed_room_center().round()


func _title_intro_fixed_room_center() -> Vector2:
	if foreground_mask != null:
		var marker := foreground_mask.get_node_or_null("TownInteriorCameraCenter") as Marker2D
		if marker != null:
			return marker.global_position
		var interior_room := foreground_mask.get_node_or_null("InteriorRoom") as Node2D
		if interior_room != null:
			return interior_room.global_position + TITLE_HOME_CAMERA_OFFSET
	return camera.global_position


func _align_title_center_to_fixed_room_x(center: Vector2) -> Vector2:
	return Vector2(_title_intro_fixed_room_center().x, center.y).round()


func _title_intro_room_entry_zoom() -> Vector2:
	return title_intro_camera_zoom * TITLE_ROOM_CAMERA_ZOOM_MULTIPLIER


func _set_player_input_locked(locked: bool) -> void:
	if player != null and player.has_method("set_input_locked"):
		player.call("set_input_locked", locked)


func _on_title_quit_requested() -> void:
	get_tree().quit()

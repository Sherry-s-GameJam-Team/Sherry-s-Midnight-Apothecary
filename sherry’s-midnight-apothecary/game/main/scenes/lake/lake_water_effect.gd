class_name LakeWaterEffect
extends Node2D

## Lightweight pixel-art lake reflection.
##
## The six grayscale masks are loaded from [member ripple_masks_directory].
## Adjacent frames are cross-faded in the shader: this softens temporal changes
## without enabling bilinear texture filtering or spatial blur.

@export_group("Lake Water")
## Ripple-mask animation rate in frames per second. Values below 2 suit calm water.
@export_range(0.05, 6.0, 0.05) var ripple_speed := 0.8
## Maximum horizontal reflection displacement, measured in logical pixels.
@export_range(0.0, 4.0, 0.05) var ripple_strength := 0.75
## Overall opacity of the reflected scenery.
@export_range(0.0, 1.0, 0.01) var reflection_strength := 0.36
## Fraction of water depth over which reflection fades out from the shoreline.
@export_range(0.05, 1.0, 0.01) var reflection_fade := 0.82
## Brightness of short ripple highlights. Keep this low to avoid flashing.
@export_range(0.0, 0.5, 0.01) var highlight_strength := 0.10
## Size of one logical pixel used for UV snapping and displacement.
@export_range(1.0, 8.0, 1.0) var pixel_size := 1.0

@export_group("Reflection Source")
## Optional upright reflection artwork. When empty, the SubViewport captures the
## source sprites listed below. The shader flips the source vertically.
@export var reflection_texture: Texture2D
## Horizontal resolution of the reflection capture. Lower values are cheaper and
## chunkier; 640-960 is normally enough for a 1280 px pixel-art viewport.
@export_range(160, 1920, 1) var reflection_resolution_width := 960

@export_group("Ripple Masks")
## Directory containing ripple_mask_01.png ... ripple_mask_06.png.
@export_dir var ripple_masks_directory := "res://game/main/scenes/lake/art/ripple_masks"

@export_group("Node References")
@export_node_path("Sprite2D") var water_base_path: NodePath = NodePath("WaterBase")
@export_node_path("Sprite2D") var reflection_display_path: NodePath = NodePath("ReflectionDisplay")
@export_node_path("Sprite2D") var ripple_highlight_path: NodePath = NodePath("RippleHighlight")
@export_node_path("SubViewport") var reflection_viewport_path: NodePath = NodePath("ReflectionViewport")
@export_node_path("Camera2D") var reflection_camera_path: NodePath = NodePath("ReflectionViewport/ReflectionCamera")
@export_node_path("CharacterBody2D") var player_path: NodePath
@export_node_path("AnimatedSprite2D") var reflection_player_path: NodePath
@export_node_path("Sprite2D") var far_source_path: NodePath
@export_node_path("Sprite2D") var port_source_path: NodePath
@export_node_path("Sprite2D") var posts_source_path: NodePath
@export_node_path("Sprite2D") var far_capture_path: NodePath
@export_node_path("Sprite2D") var port_capture_path: NodePath
@export_node_path("Sprite2D") var posts_capture_path: NodePath

@onready var water_base := get_node_or_null(water_base_path) as Sprite2D
@onready var reflection_display := get_node_or_null(reflection_display_path) as Sprite2D
@onready var ripple_highlight := get_node_or_null(ripple_highlight_path) as Sprite2D
@onready var reflection_viewport := get_node_or_null(reflection_viewport_path) as SubViewport
@onready var reflection_camera := get_node_or_null(reflection_camera_path) as Camera2D
@onready var player := get_node_or_null(player_path) as CharacterBody2D
@onready var reflection_player := get_node_or_null(reflection_player_path) as AnimatedSprite2D
@onready var far_source := get_node_or_null(far_source_path) as Sprite2D
@onready var port_source := get_node_or_null(port_source_path) as Sprite2D
@onready var posts_source := get_node_or_null(posts_source_path) as Sprite2D
@onready var far_capture := get_node_or_null(far_capture_path) as Sprite2D
@onready var port_capture := get_node_or_null(port_capture_path) as Sprite2D
@onready var posts_capture := get_node_or_null(posts_capture_path) as Sprite2D

var _ripple_masks: Array[Texture2D] = []
var _animation_position := 0.0
var _frame_index := -1
var _reflection_material: ShaderMaterial
var _highlight_material: ShaderMaterial


func _ready() -> void:
	if water_base == null or water_base.texture == null \
		or reflection_display == null or ripple_highlight == null:
		push_error("LakeWaterEffect requires WaterBase, ReflectionDisplay, and RippleHighlight.")
		set_process(false)
		return

	_ripple_masks = _load_ripple_masks(ripple_masks_directory)
	if _ripple_masks.is_empty():
		push_error("No ripple-mask PNG files found in %s." % ripple_masks_directory)
		set_process(false)
		return
	if _ripple_masks.size() != 6:
		push_warning("LakeWaterEffect expected 6 ripple masks, found %d." % _ripple_masks.size())

	# Each lake instance owns its parameters; editing one instance cannot mutate another.
	_reflection_material = _make_local_material(reflection_display)
	_highlight_material = _make_local_material(ripple_highlight)
	if _reflection_material == null or _highlight_material == null:
		push_error("LakeWaterEffect display nodes require ShaderMaterial resources.")
		set_process(false)
		return

	_configure_reflection_source()
	_configure_geometry()
	_apply_static_shader_parameters()
	_apply_animation_frame(0, 0.0)


func _process(delta: float) -> void:
	if reflection_texture == null:
		_sync_capture_sources()

	_animation_position = fmod(
		_animation_position + delta * maxf(ripple_speed, 0.0),
		float(_ripple_masks.size())
	)
	var current_index := int(floor(_animation_position))
	var frame_blend := _animation_position - float(current_index)
	_apply_animation_frame(current_index, frame_blend)


## Loads all PNGs in lexical order, so zero-padded names play in frame order.
func _load_ripple_masks(directory_path: String) -> Array[Texture2D]:
	var loaded_masks: Array[Texture2D] = []
	var file_names := DirAccess.get_files_at(directory_path)
	file_names.sort()
	for file_name in file_names:
		if file_name.get_extension().to_lower() != "png":
			continue
		var texture := ResourceLoader.load(
			directory_path.path_join(file_name),
			"Texture2D",
		) as Texture2D
		if texture != null:
			loaded_masks.append(texture)
		else:
			push_warning("Could not load ripple mask: %s" % file_name)
	return loaded_masks


func _make_local_material(sprite: Sprite2D) -> ShaderMaterial:
	var shader_material := sprite.material as ShaderMaterial
	if shader_material == null:
		return null
	shader_material = shader_material.duplicate() as ShaderMaterial
	sprite.material = shader_material
	return shader_material


func _configure_reflection_source() -> void:
	if reflection_texture != null:
		reflection_display.texture = reflection_texture
		if reflection_viewport != null:
			reflection_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return

	if reflection_viewport == null or reflection_camera == null:
		push_error("Viewport reflection needs ReflectionViewport and ReflectionCamera.")
		set_process(false)
		return
	reflection_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	reflection_display.texture = reflection_viewport.get_texture()


func _configure_geometry() -> void:
	var source_texture := reflection_display.texture
	if source_texture == null:
		return

	var water_texture_size := water_base.texture.get_size()
	var local_water_size := Vector2(
		water_texture_size.x * absf(water_base.scale.x),
		water_texture_size.y * absf(water_base.scale.y),
	)
	var global_water_size := Vector2(
		water_texture_size.x * absf(water_base.global_scale.x),
		water_texture_size.y * absf(water_base.global_scale.y),
	)

	if reflection_texture == null and reflection_viewport != null:
		var render_width := reflection_resolution_width
		var render_height := maxi(
			32,
			roundi(float(render_width) * global_water_size.y / global_water_size.x),
		)
		reflection_viewport.size = Vector2i(render_width, render_height)

		# Capture a band immediately above the waterline. It is flipped only when
		# sampled by the shader, so the shoreline remains the reflection origin.
		var world_units_per_capture_pixel := global_water_size.x / float(render_width)
		reflection_camera.zoom = Vector2.ONE / world_units_per_capture_pixel
		reflection_camera.global_position = Vector2(
			water_base.global_position.x + global_water_size.x * 0.5,
			water_base.global_position.y - global_water_size.y * 0.5,
		)
		source_texture = reflection_viewport.get_texture()

	reflection_display.position = water_base.position
	reflection_display.scale = local_water_size / Vector2(source_texture.get_size())
	ripple_highlight.position = water_base.position
	ripple_highlight.scale = local_water_size / Vector2(_ripple_masks[0].get_size())


func _apply_static_shader_parameters() -> void:
	_reflection_material.set_shader_parameter("water_region_mask", water_base.texture)
	_reflection_material.set_shader_parameter("ripple_strength", ripple_strength)
	_reflection_material.set_shader_parameter("reflection_strength", reflection_strength)
	_reflection_material.set_shader_parameter("reflection_fade", reflection_fade)
	_reflection_material.set_shader_parameter("pixel_size", pixel_size)
	_highlight_material.set_shader_parameter("highlight_strength", highlight_strength)
	_highlight_material.set_shader_parameter("pixel_size", pixel_size)


func _apply_animation_frame(index: int, blend: float) -> void:
	var current_index := index % _ripple_masks.size()
	var next_index := (current_index + 1) % _ripple_masks.size()
	if current_index != _frame_index:
		_frame_index = current_index
		ripple_highlight.texture = _ripple_masks[current_index]
		_reflection_material.set_shader_parameter(
			"ripple_mask_current",
			_ripple_masks[current_index],
		)
		_reflection_material.set_shader_parameter(
			"ripple_mask_next",
			_ripple_masks[next_index],
		)
		_highlight_material.set_shader_parameter(
			"ripple_mask_next",
			_ripple_masks[next_index],
		)
	_reflection_material.set_shader_parameter("frame_blend", blend)
	_highlight_material.set_shader_parameter("frame_blend", blend)


func _sync_capture_sources() -> void:
	_copy_sprite(far_source, far_capture)
	_copy_sprite(port_source, port_capture)
	_copy_sprite(posts_source, posts_capture)
	_sync_player_capture()


func _copy_sprite(source: Sprite2D, capture: Sprite2D) -> void:
	if source == null or capture == null:
		return
	capture.texture = source.texture
	capture.global_position = source.global_position
	capture.global_scale = source.global_scale
	capture.global_rotation = source.global_rotation
	capture.flip_h = source.flip_h
	capture.flip_v = source.flip_v
	capture.modulate = source.modulate
	capture.visible = source.visible


func _sync_player_capture() -> void:
	if player == null or reflection_player == null:
		return
	var player_sprite := player.get_node_or_null("SpritePivot/WitchSprite") as AnimatedSprite2D
	if player_sprite == null:
		reflection_player.visible = false
		return

	reflection_player.visible = player_sprite.visible
	reflection_player.global_position = player_sprite.global_position
	reflection_player.global_scale = player_sprite.global_scale
	reflection_player.global_rotation = player_sprite.global_rotation
	reflection_player.sprite_frames = player_sprite.sprite_frames
	reflection_player.animation = player_sprite.animation
	reflection_player.frame = player_sprite.frame
	reflection_player.frame_progress = player_sprite.frame_progress
	reflection_player.flip_h = player_sprite.flip_h
	reflection_player.flip_v = player_sprite.flip_v
	reflection_player.modulate = player_sprite.modulate

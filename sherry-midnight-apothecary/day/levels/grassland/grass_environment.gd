class_name GrasslandEnvironment
extends DayLevelEnvironment

## Emit this signal from gameplay code to request a texture-state transition.
signal texture_state_requested(corrupted: bool)
signal texture_state_changed(corrupted: bool)

const NORMAL_SKYBOX := preload("res://day/levels/grassland/art/skybox.png")
const CORRUPTED_SKYBOX := preload("res://day/levels/grassland/art/skybox_corruped.png")
const NORMAL_FAR_GRASS := preload("res://day/levels/grassland/art/fs_grass.png")
const CORRUPTED_FAR_GRASS := preload("res://day/levels/grassland/art/fs_grass_corruped.png")
const NORMAL_GRASS_LOOP := preload("res://day/levels/grassland/art/grass_loop.png")
const CORRUPTED_GRASS_LOOP := preload("res://day/levels/grassland/art/grass_corrupted_loop.png")
const DEVELOPER_CONSOLE_SCENE_PATH := "res://night/ui/developer_console/developer_console.tscn"
const MIASMA_CLEARED_FLAG := "emerald_field_miasma_cleared"

func _init() -> void:
	texture_state_requested.connect(_on_texture_state_requested)


func _ready() -> void:
	super()
	_install_standalone_developer_console()
	# Completing the Emerald Field OSU purifier persists the normal Grassland
	# artwork across the return transition and any later reloads.
	var miasma_cleared := bool(get_player_data().tutorial_flags.get(MIASMA_CLEARED_FLAG, false))
	_apply_texture_state(start_corrupted and not miasma_cleared, true)

func _install_standalone_developer_console() -> void:
	if _is_embedded_in_day_runtime():
		return
	var debug_ui := get_node_or_null("DebugUI") as CanvasLayer
	if debug_ui == null or debug_ui.get_node_or_null("DeveloperConsole") != null:
		return
	var console_scene := load(DEVELOPER_CONSOLE_SCENE_PATH) as PackedScene
	if console_scene == null:
		push_error("Grassland could not load DeveloperConsole.")
		return
	var console := console_scene.instantiate()
	debug_ui.add_child(console)
	console.call("setup_day_scene", self)


func _is_embedded_in_day_runtime() -> bool:
	var host := get_parent()
	return host != null and host.get_parent() != null and host.get_parent().has_method("get_player_data")

func set_corrupted(corrupted: bool) -> void:
	texture_state_requested.emit(corrupted)


func to_normal() -> void:
	set_corrupted(false)


func to_corrupted() -> void:
	set_corrupted(true)


func is_corrupted() -> bool:
	return _is_corrupted


func _on_texture_state_requested(corrupted: bool) -> void:
	_apply_texture_state(corrupted)


func _apply_texture_state(corrupted: bool, force := false) -> void:
	if not force and _is_corrupted == corrupted:
		return
	_set_sprite_texture(NodePath("Skybox/Artwork"), CORRUPTED_SKYBOX if corrupted else NORMAL_SKYBOX)
	_set_corrupted_horizon_visible(corrupted)
	_set_corrupted_holes_visible(corrupted)
	_set_trapezoid_visible(corrupted)
	_set_sprite_texture(NodePath("FarGrass/Artwork"), CORRUPTED_FAR_GRASS if corrupted else NORMAL_FAR_GRASS)
	var grass_texture: Texture2D = CORRUPTED_GRASS_LOOP if corrupted else NORMAL_GRASS_LOOP
	for node: Sprite2D in _grass_loop_sprites():
		node.texture = grass_texture
	_is_corrupted = corrupted
	if force:
		return
	environment_state_changed.emit(corrupted)
	texture_state_changed.emit(corrupted)


func _grass_loop_sprites() -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	for node: Node in find_children("GrassLoop*", "Sprite2D", true, false):
		sprites.append(node as Sprite2D)
	return sprites

func _set_sprite_texture(node_path: NodePath, texture: Texture2D) -> void:
	var sprite := get_node_or_null(node_path) as Sprite2D
	if sprite == null:
		push_error("Grassland texture target is missing: %s" % node_path)
		return
	sprite.texture = texture


func _set_corrupted_horizon_visible(corrupted: bool) -> void:
	var horizon := get_node_or_null("CorruptedHorizon") as Parallax2D
	if horizon == null:
		push_error("Grassland corrupted horizon is missing.")
		return
	horizon.visible = corrupted


func _set_corrupted_holes_visible(corrupted: bool) -> void:
	for node_path in [NodePath("Foreground/HoleLeft"), NodePath("Foreground/HoleRight")]:
		var hole := get_node_or_null(node_path) as CanvasItem
		if hole == null:
			push_error("Grassland corrupted-hole target is missing: %s" % node_path)
			continue
		hole.visible = corrupted


func _set_trapezoid_visible(corrupted: bool) -> void:
	var trapezoid := get_node_or_null("Trapezoid") as CanvasItem
	if trapezoid == null:
		push_error("Grassland Trapezoid is missing.")
		return
	trapezoid.visible = corrupted

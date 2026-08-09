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

const GRASS_LOOP_PATHS: Array[NodePath] = [
	NodePath("FarGrass/GrassLoop2"),
	NodePath("FarGrass/GrassLoop3"),
	NodePath("Foreground/GrassLoop2"),
	NodePath("Foreground/GrassLoop"),
]

@export var start_corrupted := false

var _is_corrupted := false


func _init() -> void:
	texture_state_requested.connect(_on_texture_state_requested)


func _ready() -> void:
	super()
	_apply_texture_state(start_corrupted, true)


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
	_set_sprite_texture(NodePath("FarGrass/Artwork"), CORRUPTED_FAR_GRASS if corrupted else NORMAL_FAR_GRASS)
	var grass_texture: Texture2D = CORRUPTED_GRASS_LOOP if corrupted else NORMAL_GRASS_LOOP
	for node_path in GRASS_LOOP_PATHS:
		_set_sprite_texture(node_path, grass_texture)
	_is_corrupted = corrupted
	if not force:
		texture_state_changed.emit(corrupted)


func _set_sprite_texture(node_path: NodePath, texture: Texture2D) -> void:
	var sprite := get_node_or_null(node_path) as Sprite2D
	if sprite == null:
		push_error("Grassland texture target is missing: %s" % node_path)
		return
	sprite.texture = texture

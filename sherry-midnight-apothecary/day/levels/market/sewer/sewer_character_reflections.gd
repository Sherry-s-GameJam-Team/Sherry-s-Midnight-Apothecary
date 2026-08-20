class_name SewerCharacterReflections
extends Node2D

## Mirrors the visible character presentation below the blood-water line. The
## duplicate visuals are deliberately presentation-only; collisions and input
## remain exclusively on the real Sherry and Luca nodes.
@export var player_path: NodePath
@export var luca_path: NodePath
@export var sherry_reflection_path: NodePath
@export var luca_reflection_path: NodePath
@export var waterline_y := 516.0
@export_range(0.05, 1.0, 0.01) var vertical_compression := 0.2
@export var reflection_material: ShaderMaterial

var _player: CharacterBody2D
var _luca: LucaPlayer
var _sherry_reflection: Node2D
var _luca_reflection: Node2D
var _sherry_animation: AnimationPlayer
var _sherry_reflection_animation: AnimationPlayer
var _luca_sprite: AnimatedSprite2D
var _luca_reflection_sprite: Sprite2D
var _sherry_reflection_visual: CanvasItem


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_luca = get_node_or_null(luca_path) as LucaPlayer
	_sherry_reflection = get_node_or_null(sherry_reflection_path) as Node2D
	_luca_reflection = get_node_or_null(luca_reflection_path) as Node2D
	if _player == null or _sherry_reflection == null:
		push_warning("SewerCharacterReflections requires Sherry and her mirrored presentation.")
		set_process(false)
		return
	_sherry_animation = _player.get_node_or_null("SherryPresentation/SherryAnimationPlayer") as AnimationPlayer
	_sherry_reflection_animation = _sherry_reflection.get_node_or_null("SherryAnimationPlayer") as AnimationPlayer
	_sherry_reflection_visual = _sherry_reflection.get_node_or_null("SherrySprite/SherryVisual") as CanvasItem
	if _luca != null and _luca_reflection != null:
		_luca_sprite = _luca.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		_luca_reflection_sprite = _luca_reflection.get_node_or_null("LucaVisual") as Sprite2D
	_apply_reflection_material()
	_initialize_luca_reflection()


func _process(_delta: float) -> void:
	_mirror_node(_player, _sherry_reflection)
	if _luca != null and _luca_reflection != null:
		_mirror_node(_luca, _luca_reflection)
	_sync_sherry_animation()
	if _luca != null and _luca_reflection != null:
		_sync_luca_animation()


func _mirror_node(source: Node2D, reflection: Node2D) -> void:
	# A compressed mirror still shares the same reflection axis, but fits the
	# deliberately shallow strip of water painted in this level's source art.
	var mirrored_depth := (waterline_y - source.global_position.y) * vertical_compression
	reflection.global_position = Vector2(source.global_position.x, waterline_y + mirrored_depth)
	reflection.scale = Vector2(1.0, -vertical_compression)
	# Luca's collision origin settles a few pixels below the visual waterline.
	# Visibility must follow the source alone; the water alpha mask in the shader
	# is the authoritative boundary for whether any reflection pixels are drawn.
	reflection.visible = source.visible


func _sync_sherry_animation() -> void:
	if _sherry_animation == null or _sherry_reflection_animation == null:
		return
	var animation := _sherry_animation.current_animation
	if animation.is_empty():
		return
	if _sherry_reflection_animation.current_animation != animation:
		_sherry_reflection_animation.play(animation)
	_sherry_reflection_animation.seek(_sherry_animation.current_animation_position, true)


func _sync_luca_animation() -> void:
	if _luca_sprite == null or _luca_reflection_sprite == null:
		return
	var frames := _luca_sprite.sprite_frames
	if frames == null or not frames.has_animation(_luca_sprite.animation):
		return
	_luca_reflection_sprite.texture = frames.get_frame_texture(_luca_sprite.animation, _luca_sprite.frame)
	_luca_reflection_sprite.flip_h = _luca_sprite.flip_h


func _apply_reflection_material() -> void:
	if reflection_material == null:
		push_warning("SewerCharacterReflections requires a reflection ShaderMaterial.")
		return
	# Bind at runtime: inherited-child material overrides are not dependable when
	# the reflected Sherry presentation is an instanced scene.
	if _sherry_reflection_visual != null:
		_sherry_reflection_visual.material = reflection_material
	if _luca_reflection_sprite != null:
		_luca_reflection_sprite.material = reflection_material


func _initialize_luca_reflection() -> void:
	if _luca_reflection_sprite == null:
		return
	_luca_reflection_sprite.visible = true

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

var _player: CharacterBody2D
var _luca: LucaPlayer
var _sherry_reflection: Node2D
var _luca_reflection: Node2D
var _sherry_animation: AnimationPlayer
var _sherry_reflection_animation: AnimationPlayer
var _luca_sprite: AnimatedSprite2D
var _luca_reflection_sprite: AnimatedSprite2D


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_luca = get_node_or_null(luca_path) as LucaPlayer
	_sherry_reflection = get_node_or_null(sherry_reflection_path) as Node2D
	_luca_reflection = get_node_or_null(luca_reflection_path) as Node2D
	if _player == null or _luca == null or _sherry_reflection == null or _luca_reflection == null:
		push_warning("SewerCharacterReflections requires both characters and mirrored presentations.")
		set_process(false)
		return
	_sherry_animation = _player.get_node_or_null("SherryPresentation/SherryAnimationPlayer") as AnimationPlayer
	_sherry_reflection_animation = _sherry_reflection.get_node_or_null("SherryAnimationPlayer") as AnimationPlayer
	_luca_sprite = _luca.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_luca_reflection_sprite = _luca_reflection.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _process(_delta: float) -> void:
	_mirror_node(_player, _sherry_reflection)
	_mirror_node(_luca, _luca_reflection)
	_sync_sherry_animation()
	_sync_luca_animation()


func _mirror_node(source: Node2D, reflection: Node2D) -> void:
	reflection.global_position = Vector2(source.global_position.x, waterline_y * 2.0 - source.global_position.y)
	reflection.scale = Vector2(1.0, -1.0)
	reflection.visible = source.visible and source.global_position.y <= waterline_y


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
	_luca_reflection_sprite.animation = _luca_sprite.animation
	_luca_reflection_sprite.frame = _luca_sprite.frame
	_luca_reflection_sprite.frame_progress = _luca_sprite.frame_progress
	_luca_reflection_sprite.flip_h = _luca_sprite.flip_h

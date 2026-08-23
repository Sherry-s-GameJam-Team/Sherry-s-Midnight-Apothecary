class_name CrownlandMagicPillar
extends Node2D
## 黑魔法柱子 (Stage 2 可破坏目标) / Stage-2 Destructible Magic Pillar
##
## Receives receive_potion_hit(hit: Dictionary) from the potion throw system.
## Blue/purification potions deal +1 bonus damage (configurable).
## On destruction: swap visual → play explosion frames → emit pillar_destroyed.

signal pillar_hp_changed(pillar_id: StringName, remaining_hp: int)
signal pillar_destroyed(pillar_id: StringName)

@export var pillar_id: StringName = &"pillar_left"
@export var pillar_hp: int = 3
@export var purify_bonus_damage: int = 1   # added on top of base 1

## Visual textures (assign in Inspector)
@export var intact_texture: Texture2D       ## 黑魔法柱子.png
@export var broken_texture: Texture2D       ## 破碎的黑魔法柱子.png
@export var explosion_frame_textures: Array[Texture2D] = []  ## [爆破帧1-4]

@export var explosion_fps: float = 12.0

# Pillar tags that identify blue/purification potions
const PURIFY_TAGS: Array[String] = ["blue", "pure", "purify", "purification", "cyan", "ice", "净化"]
const INTACT_VISUAL_SCALE := Vector2(0.10, 0.10)
const BROKEN_VISUAL_SCALE := Vector2(0.30, 0.30)
const PILLAR_REST_Y := -77.0

var _current_hp: int = 0
var _is_destroyed: bool = false
var _can_receive_hits: bool = false

var _pillar_sprite: Sprite2D
var _hurtbox: Area2D
var _hurtbox_shape: CollisionShape2D
var _flash_tween: Tween


func _ready() -> void:
	_current_hp = pillar_hp

	# Visual
	_pillar_sprite = Sprite2D.new()
	_pillar_sprite.name = "PillarSprite"
	add_child(_pillar_sprite)
	refresh_visual_texture()

	# Prefer the editor-authored Hurtbox in crownland_boss_arena.tscn. Keeping
	# the fallback preserves this script's reuse in isolated test scenes.
	_hurtbox = get_node_or_null("Hurtbox") as Area2D
	if _hurtbox == null:
		_hurtbox = Area2D.new()
		_hurtbox.name = "Hurtbox"
		add_child(_hurtbox)
	_hurtbox.collision_layer = 4 # visible to PotionProjectile's physics query
	_hurtbox.collision_mask = 0
	_hurtbox.monitoring = true
	_hurtbox.monitorable = true

	_hurtbox_shape = _hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _hurtbox_shape == null:
		_hurtbox_shape = CollisionShape2D.new()
		_hurtbox_shape.name = "CollisionShape2D"
		_hurtbox.add_child(_hurtbox_shape)
	if _hurtbox_shape.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(44, 130)
		_hurtbox_shape.shape = rect
	_hurtbox_shape.position = Vector2(0, -65)

	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)


## Called by arena setup to enable potion hits once Stage 2 begins.
func set_vulnerable(vulnerable: bool) -> void:
	_can_receive_hits = vulnerable
	if _hurtbox != null:
		_hurtbox.monitoring = vulnerable


## Called by potion throw system (same interface as Boss).
func receive_potion_hit(hit: Dictionary) -> void:
	if _is_destroyed or not _can_receive_hits:
		return
	var potion_id: String = String(hit.get("potion_id", ""))
	var is_purify: bool = _is_purification(potion_id)
	var damage: int = 1 + (purify_bonus_damage if is_purify else 0)
	_apply_hit(damage)


## Called when a potion Area2D physically overlaps the hurtbox.
func _on_hurtbox_area_entered(area: Area2D) -> void:
	if _is_destroyed or not _can_receive_hits:
		return
	# Potions may call receive_potion_hit on us, or we handle directly here
	if area.has_method("receive_potion_hit"):
		return   # already handled via receive_potion_hit call
	# Fallback: treat any overlapping area as a hit
	_apply_hit(1)


func _is_purification(potion_id: String) -> bool:
	for tag: String in PURIFY_TAGS:
		if tag in potion_id:
			return true
	return false


func _apply_hit(damage: int) -> void:
	_current_hp = maxi(0, _current_hp - damage)
	pillar_hp_changed.emit(pillar_id, _current_hp)

	if _current_hp <= 0:
		_destroy()
	else:
		_play_hit_flash()


func _play_hit_flash() -> void:
	if _pillar_sprite == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	if _flash_tween != null:
		_flash_tween.tween_property(_pillar_sprite, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.05)
		_flash_tween.tween_property(_pillar_sprite, "modulate", Color.WHITE, 0.1)


## Called by CrownlandAssetLoader after assigning runtime textures.
func refresh_visual_texture() -> void:
	if _pillar_sprite == null:
		return
	if _is_destroyed:
		_pillar_sprite.texture = broken_texture
		_pillar_sprite.scale = BROKEN_VISUAL_SCALE
	else:
		_pillar_sprite.texture = intact_texture
		_pillar_sprite.scale = INTACT_VISUAL_SCALE
	_pillar_sprite.position = Vector2(0.0, PILLAR_REST_Y)


func _destroy() -> void:
	_is_destroyed = true
	if _hurtbox != null:
		_hurtbox.monitoring = false

	# Swap to broken texture
	refresh_visual_texture()

	# Spawn explosion FX as sibling
	if not explosion_frame_textures.is_empty():
		var fx := CrownlandExplosionFx.new()
		fx.frame_textures = explosion_frame_textures
		fx.fps = explosion_fps
		fx.scale_factor = 1.2
		fx.global_position = global_position + Vector2(0, -65)
		get_parent().add_child(fx)

	pillar_destroyed.emit(pillar_id)

	# Fade out broken sprite after brief pause
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			await tree.create_timer(1.0).timeout
	if _pillar_sprite != null:
		var tween := create_tween()
		if tween != null:
			tween.tween_property(_pillar_sprite, "modulate:a", 0.0, 0.6)


func _draw() -> void:
	if intact_texture == null and not _is_destroyed:
		draw_rect(Rect2(-22, -130, 44, 130), Color(0.1, 0.0, 0.3, 0.9))
	elif broken_texture == null and _is_destroyed:
		draw_rect(Rect2(-22, -130, 44, 130), Color(0.3, 0.1, 0.3, 0.5))

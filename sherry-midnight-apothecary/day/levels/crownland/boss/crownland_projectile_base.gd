class_name CrownlandProjectileBase
extends Area2D
## Base class for all Crownland boss projectiles.
##
## Provides:
##  - Off-screen auto-destroy (300 px margin beyond camera viewport)
##  - Single-hit-per-player guard (invulnerability-frame compatible)
##  - Parent-walk damage application (apply_player_damage / apply_fall_or_hazard_damage)
##  - cleanup() for bulk clearing by BattleDirector

## How far outside the viewport (px) before auto-destroy.
@export var offscreen_margin: float = 300.0
## Maximum lifetime regardless of screen position (safety net).
@export var max_lifetime: float = 12.0

var _damage: int = 0
var _has_hit_player: bool = false
var _lifetime: float = 0.0
var _active: bool = false

# Subclasses must call _init_base() in their own _ready() after setting up shapes.
func _init_base(damage: int) -> void:
	_damage = damage
	_active = true
	# Connect body_entered if not already done
	if not body_entered.is_connected(_on_base_body_entered):
		body_entered.connect(_on_base_body_entered)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_lifetime += delta
	if _lifetime >= max_lifetime:
		_destroy()
		return
	# Off-screen check
	if _is_offscreen():
		_destroy()


func _is_offscreen() -> bool:
	if not is_inside_tree():
		return false
	var vp := get_viewport()
	if vp == null:
		return false
	var cam := vp.get_camera_2d()
	if cam == null:
		# Fallback: use viewport rect
		var vp_rect := vp.get_visible_rect()
		var local_pos := global_position - vp_rect.position
		return (local_pos.x < -offscreen_margin or
				local_pos.x > vp_rect.size.x + offscreen_margin or
				local_pos.y < -offscreen_margin or
				local_pos.y > vp_rect.size.y + offscreen_margin)
	var cam_pos := cam.global_position
	var half_size := vp.get_visible_rect().size * 0.5 / cam.zoom
	return (global_position.x < cam_pos.x - half_size.x - offscreen_margin or
			global_position.x > cam_pos.x + half_size.x + offscreen_margin or
			global_position.y < cam_pos.y - half_size.y - offscreen_margin or
			global_position.y > cam_pos.y + half_size.y + offscreen_margin)


func _on_base_body_entered(body: Node2D) -> void:
	if _has_hit_player:
		return
	if body.is_in_group("player") or body.name == "Player":
		_has_hit_player = true
		_apply_damage_to_body(body)
		_on_player_hit(body)
		_destroy()


## Override in subclass to add custom behavior on player hit (e.g. explosion).
func _on_player_hit(_player: Node2D) -> void:
	pass


func _apply_damage_to_body(_body: Node2D) -> void:
	_walk_and_damage()


func _walk_and_damage() -> void:
	var node: Node = self
	while node != null:
		if node.has_method("apply_player_damage"):
			node.call("apply_player_damage", _damage, self)
			return
		if node.has_method("apply_fall_or_hazard_damage"):
			node.call("apply_fall_or_hazard_damage", _damage, str(name))
			return
		node = node.get_parent()
	# Last-resort: try scene tree group
	if is_inside_tree():
		var tree := get_tree()
		if tree != null:
			var player := tree.get_first_node_in_group("player")
			if player != null and player.has_method("take_damage"):
				player.call("take_damage", _damage, self)


## Called by BattleDirector.cleanup_all() — graceful removal without errors.
func cleanup() -> void:
	_active = false
	queue_free()


func _destroy() -> void:
	_active = false
	queue_free()


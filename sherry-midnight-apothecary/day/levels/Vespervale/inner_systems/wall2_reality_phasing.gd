class_name Wall2RealityPhasing
extends Node2D

## Reality-State Phasing Controller for wall2 in Vespervale Inner.
## When entering Reality state (Luca active), wall2 and its collision box
## disappear briefly with a smooth visual fade, allowing passage before reappearing.

signal wall_phased_out
signal wall_phased_in

@export var disappear_duration: float = 3.5
@export var fade_duration: float = 0.35
@export var periodic_in_reality: bool = false
@export var periodic_interval: float = 3.0
@export var party_controller_path: NodePath = NodePath("../../../InnerPartyController")

var _is_phased_out: bool = false
var _disappear_timer: float = 0.0
var _reappear_timer: float = 0.0
var _tween: Tween = null

@onready var wall2_sprite: Sprite2D = (self if self is Sprite2D else get_parent()) as Sprite2D
@onready var static_body: StaticBody2D = get_node_or_null("StaticBody2D") if self is Sprite2D else get_node_or_null("../StaticBody2D")
@onready var collision_poly: CollisionPolygon2D = get_node_or_null("StaticBody2D/CollisionPolygon2D") if self is Sprite2D else get_node_or_null("../StaticBody2D/CollisionPolygon2D")
@onready var party_controller: InnerPartyController = get_node_or_null(party_controller_path) as InnerPartyController


func _ready() -> void:
	_init_system_references()
	_set_wall_solid_instant()


func _init_system_references() -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	if party_controller == null:
		party_controller = root.get_node_or_null("InnerPartyController") as InnerPartyController

	if party_controller != null and not party_controller.active_character_changed.is_connected(_on_active_character_changed):
		party_controller.active_character_changed.connect(_on_active_character_changed)

	if wall2_sprite == null:
		wall2_sprite = root.find_child("wall2", true, false) as Sprite2D
	if wall2_sprite != null:
		if static_body == null:
			static_body = wall2_sprite.get_node_or_null("StaticBody2D") as StaticBody2D
		if collision_poly == null and static_body != null:
			collision_poly = static_body.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D


func _process(delta: float) -> void:
	if _disappear_timer > 0.0:
		_disappear_timer -= delta
		if _disappear_timer <= 0.0:
			_phase_in_wall()

	elif periodic_in_reality and _is_reality_active():
		if not _is_phased_out:
			_reappear_timer -= delta
			if _reappear_timer <= 0.0:
				_phase_out_wall()


func _on_active_character_changed(character_id: StringName) -> void:
	if character_id == &"luca":
		# Switched to Reality (Luca) -> Trigger temporary disappearance
		_phase_out_wall()
	else:
		# Switched to Dream (Sherry) -> Restore solid wall immediately
		_disappear_timer = 0.0
		_set_wall_solid_instant()


func _is_reality_active() -> bool:
	if party_controller != null:
		return party_controller.active_character == &"luca"
	return false


func _phase_out_wall() -> void:
	_is_phased_out = true
	_disappear_timer = disappear_duration

	# Disable collision box
	if collision_poly != null:
		collision_poly.set_deferred("disabled", true)
	if static_body != null:
		static_body.collision_layer = 0
		static_body.collision_mask = 0

	# Smooth visual fade out
	if wall2_sprite != null:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(wall2_sprite, "modulate:a", 0.12, fade_duration)

	wall_phased_out.emit()


func _phase_in_wall() -> void:
	_is_phased_out = false
	_reappear_timer = periodic_interval

	# Enable collision box
	if collision_poly != null:
		collision_poly.set_deferred("disabled", false)
	if static_body != null:
		static_body.collision_layer = 1 | 2
		static_body.collision_mask = 0

	# Smooth visual fade in
	if wall2_sprite != null:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(wall2_sprite, "modulate:a", 1.0, fade_duration)

	wall_phased_in.emit()


func _set_wall_solid_instant() -> void:
	_is_phased_out = false
	if _tween != null and _tween.is_valid():
		_tween.kill()

	if wall2_sprite != null:
		wall2_sprite.modulate.a = 1.0

	if collision_poly != null:
		collision_poly.set_deferred("disabled", false)
	if static_body != null:
		static_body.collision_layer = 1 | 2
		static_body.collision_mask = 0

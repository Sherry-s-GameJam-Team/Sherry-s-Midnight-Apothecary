class_name Wall2RealityPhasing
extends Node2D

## Reality-State Phasing Controller for wall2 in Vespervale Inner.
## When in Reality state (DreamShiftManager Reality Intrusion OR Luca active),
## wall2 and its collision box disappear with a smooth visual fade, allowing passage.

signal wall_phased_out
signal wall_phased_in

@export var disappear_duration: float = 3.5
@export var fade_duration: float = 0.25

var _is_phased_out: bool = false
var _tween: Tween = null

var shift_manager: DreamShiftManager = null
var party_controller: InnerPartyController = null

@onready var wall2_sprite: Sprite2D = get_parent() as Sprite2D
@onready var static_body: StaticBody2D = get_node_or_null("../StaticBody2D") as StaticBody2D
@onready var collision_poly: CollisionPolygon2D = get_node_or_null("../StaticBody2D/CollisionPolygon2D") as CollisionPolygon2D


func _ready() -> void:
	call_deferred("_init_system_references")


func _init_system_references() -> void:
	# Find node references
	if wall2_sprite == null:
		var p := get_parent()
		if p is Sprite2D:
			wall2_sprite = p as Sprite2D

	if static_body == null and wall2_sprite != null:
		static_body = wall2_sprite.get_node_or_null("StaticBody2D") as StaticBody2D

	if collision_poly == null and static_body != null:
		collision_poly = static_body.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D

	shift_manager = _find_shift_manager()
	if shift_manager != null:
		if not shift_manager.dream_state_changed.is_connected(_on_dream_state_changed):
			shift_manager.dream_state_changed.connect(_on_dream_state_changed)
		if not shift_manager.reality_intrusion_started.is_connected(_on_reality_started):
			shift_manager.reality_intrusion_started.connect(_on_reality_started)
		if not shift_manager.reality_intrusion_ended.is_connected(_on_reality_ended):
			shift_manager.reality_intrusion_ended.connect(_on_reality_ended)

	party_controller = _find_party_controller()
	if party_controller != null:
		if not party_controller.active_character_changed.is_connected(_on_character_changed):
			party_controller.active_character_changed.connect(_on_character_changed)

	_evaluate_state(false)


func _process(_delta: float) -> void:
	_evaluate_state(true)


func _evaluate_state(animate: bool) -> void:
	var in_reality := _check_if_reality()
	if in_reality and not _is_phased_out:
		_phase_out_wall(animate)
	elif not in_reality and _is_phased_out:
		_phase_in_wall(animate)


func _check_if_reality() -> bool:
	if shift_manager != null and not shift_manager.is_in_dream():
		return true
	if party_controller != null and party_controller.active_character == &"luca":
		return true
	return false


func _on_dream_state_changed(in_dream: bool) -> void:
	if in_dream:
		_evaluate_state(true)
	else:
		_phase_out_wall(true)


func _on_reality_started() -> void:
	_phase_out_wall(true)


func _on_reality_ended() -> void:
	_evaluate_state(true)


func _on_character_changed(_character_id: StringName) -> void:
	_evaluate_state(true)


func _phase_out_wall(animate: bool) -> void:
	_is_phased_out = true

	# Disable collision polygon and static body
	if collision_poly != null:
		collision_poly.set_deferred("disabled", true)
	if static_body != null:
		static_body.set_deferred("collision_layer", 0)
		static_body.set_deferred("collision_mask", 0)

	# Fade out visuals
	if wall2_sprite != null:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		if animate:
			_tween = create_tween()
			_tween.tween_property(wall2_sprite, "modulate:a", 0.0, fade_duration)
		else:
			wall2_sprite.modulate.a = 0.0

	wall_phased_out.emit()


func _phase_in_wall(animate: bool) -> void:
	_is_phased_out = false

	# Restore collision polygon and static body
	if collision_poly != null:
		collision_poly.set_deferred("disabled", false)
	if static_body != null:
		static_body.set_deferred("collision_layer", 1 | 2)
		static_body.set_deferred("collision_mask", 0)

	# Fade in visuals
	if wall2_sprite != null:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		if animate:
			_tween = create_tween()
			_tween.tween_property(wall2_sprite, "modulate:a", 1.0, fade_duration)
		else:
			wall2_sprite.modulate.a = 1.0

	wall_phased_in.emit()


func _find_shift_manager() -> DreamShiftManager:
	var cur: Node = self
	while cur != null:
		var mgr := cur.get_node_or_null("DreamShiftManager") as DreamShiftManager
		if mgr != null:
			return mgr
		cur = cur.get_parent()
	var root := get_tree().current_scene
	if root != null:
		return root.get_node_or_null("DreamShiftManager") as DreamShiftManager
	return null


func _find_party_controller() -> InnerPartyController:
	var cur: Node = self
	while cur != null:
		var pc := cur.get_node_or_null("InnerPartyController") as InnerPartyController
		if pc != null:
			return pc
		cur = cur.get_parent()
	var root := get_tree().current_scene
	if root != null:
		return root.get_node_or_null("InnerPartyController") as InnerPartyController
	return null

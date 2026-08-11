class_name DualProtagonistController
extends Node

signal actor_change_blocked(target_actor: Actor, reason: String)
signal active_actor_changed(actor: Actor)

enum Actor {
	SHERRY,
	LUCA,
}

@export var sherry_path: NodePath
@export var luca_path: NodePath
@export var camera_path: NodePath
@export var world_manager_path: NodePath
@export var switch_action := &"switch_protagonist"
@export var initial_actor := Actor.SHERRY
@export var camera_offset := Vector2(0.0, -180.0)
@export var debug_switch_warnings := true

var active_actor := Actor.SHERRY
var _switch_requested := false

@onready var sherry: CharacterBody2D = get_node(sherry_path) as CharacterBody2D
@onready var luca: CharacterBody2D = get_node(luca_path) as CharacterBody2D
@onready var camera: Camera2D = get_node(camera_path) as Camera2D
@onready var world_manager: DualWorldManager = get_node(world_manager_path) as DualWorldManager


func _ready() -> void:
	active_actor = initial_actor
	set_actor_control(sherry, active_actor == Actor.SHERRY)
	set_actor_control(luca, active_actor == Actor.LUCA)
	_follow_actor(get_active_actor_node())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(switch_action):
		request_switch()
		get_viewport().set_input_as_handled()


func get_active_actor_node() -> CharacterBody2D:
	if active_actor == Actor.SHERRY:
		return sherry
	return luca


func request_switch() -> bool:
	if _switch_requested or world_manager.is_switching:
		return false
	_switch_requested = true
	var target: Actor = Actor.LUCA
	var target_actor: CharacterBody2D = luca
	var target_world: DualWorldManager.WorldState = DualWorldManager.WorldState.ORIGINAL
	if active_actor == Actor.LUCA:
		target = Actor.SHERRY
		target_actor = sherry
		target_world = DualWorldManager.WorldState.CORRUPTED
	if not await _is_target_position_safe(target_actor, target_world):
		var reason := "%s cannot switch: saved position overlaps target-world terrain." % Actor.keys()[target]
		if debug_switch_warnings and OS.is_debug_build():
			push_warning(reason)
		actor_change_blocked.emit(target, reason)
		_switch_requested = false
		return false
	set_actor_control(get_active_actor_node(), false)
	var switched := await world_manager.change_world(target_world, func() -> void:
		active_actor = target
		_follow_actor(target_actor)
	)
	if switched:
		set_actor_control(target_actor, true)
		active_actor_changed.emit(active_actor)
	else:
		set_actor_control(get_active_actor_node(), true)
	_switch_requested = false
	return switched


## Project adapter: Sherry uses the existing callbacks unchanged; Luca already
## exposes input_enabled/stop_moving. Both actors remain instantiated and keep
## their independent transforms while the inactive collision is suspended.
func set_actor_control(actor: Node, enabled: bool) -> void:
	if actor == null:
		return
	if actor is LucaPlayer:
		(actor as LucaPlayer).input_enabled = enabled
		actor.set_physics_process(enabled)
		if not enabled:
			(actor as LucaPlayer).stop_moving()
	else:
		actor.set_physics_process(enabled)
		actor.set_process_unhandled_key_input(enabled)
		actor.set_process_unhandled_input(enabled)
		if not enabled and actor is CharacterBody2D:
			(actor as CharacterBody2D).velocity = Vector2.ZERO
	_set_actor_collision_enabled(actor, enabled)


func _follow_actor(actor: Node) -> void:
	if camera.get_parent() != actor:
		camera.reparent(actor, false)
	camera.position = camera_offset
	camera.enabled = true
	camera.make_current()


func _is_target_position_safe(actor: CharacterBody2D, world_state: DualWorldManager.WorldState) -> bool:
	var shape_node := _find_actor_shape(actor)
	if shape_node == null or shape_node.shape == null:
		return true
	world_manager.set_world_collision_enabled(world_state, true)
	await get_tree().physics_frame
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.collision_mask = actor.collision_mask
	query.exclude = [actor.get_rid()]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hits := actor.get_world_2d().direct_space_state.intersect_shape(query, 32)
	var target_root := world_manager.get_world_root(world_state)
	var overlaps_target_world := false
	for hit: Dictionary in hits:
		var collider := hit.get("collider") as Node
		if collider != null and (collider == target_root or target_root.is_ancestor_of(collider)):
			overlaps_target_world = true
			break
	if world_manager.current_world != world_state:
		world_manager.set_world_collision_enabled(world_state, false)
	return not overlaps_target_world


func _find_actor_shape(actor: Node) -> CollisionShape2D:
	for child: Node in actor.find_children("*", "CollisionShape2D", true, false):
		var shape_node := child as CollisionShape2D
		if shape_node != null and shape_node.shape != null:
			return shape_node
	return null


func _set_actor_collision_enabled(actor: Node, enabled: bool) -> void:
	for child: Node in actor.find_children("*", "CollisionShape2D", true, false):
		(child as CollisionShape2D).set_deferred("disabled", not enabled)
	for child: Node in actor.find_children("*", "CollisionPolygon2D", true, false):
		(child as CollisionPolygon2D).set_deferred("disabled", not enabled)

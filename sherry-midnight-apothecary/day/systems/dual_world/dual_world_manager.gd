class_name DualWorldManager
extends Node

signal world_change_started(from_world: WorldState, to_world: WorldState)
signal world_change_midpoint(world_state: WorldState)
signal world_collision_prepared(world_state: WorldState, enabled: bool)
signal world_changed(world_state: WorldState)

enum WorldState {
	CORRUPTED,
	ORIGINAL,
}

@export var corrupted_world_path: NodePath
@export var original_world_path: NodePath
@export var transition_overlay_path: NodePath
@export_range(0.0, 1.0, 0.01) var transition_alpha := 0.55
@export_range(0.0, 1.0, 0.01) var fade_out_duration := 0.12
@export_range(0.0, 1.0, 0.01) var fade_in_duration := 0.16
@export var initial_world := WorldState.CORRUPTED

var current_world := WorldState.CORRUPTED
var is_switching := false

@onready var corrupted_world: CanvasItem = get_node(corrupted_world_path) as CanvasItem
@onready var original_world: CanvasItem = get_node(original_world_path) as CanvasItem
@onready var transition_overlay: ColorRect = get_node_or_null(transition_overlay_path) as ColorRect


func _ready() -> void:
	current_world = initial_world
	if transition_overlay != null:
		var color := transition_overlay.color
		color.a = 0.0
		transition_overlay.color = color
	apply_world(current_world)


func get_world_root(world_state: WorldState) -> Node:
	if world_state == WorldState.CORRUPTED:
		return corrupted_world
	return original_world


func apply_world(world_state: WorldState) -> void:
	current_world = world_state
	corrupted_world.visible = world_state == WorldState.CORRUPTED
	original_world.visible = world_state == WorldState.ORIGINAL
	set_world_collision_enabled(WorldState.CORRUPTED, world_state == WorldState.CORRUPTED)
	set_world_collision_enabled(WorldState.ORIGINAL, world_state == WorldState.ORIGINAL)
	world_changed.emit(current_world)


func set_world_collision_enabled(world_state: WorldState, enabled: bool) -> void:
	_set_collision_tree(get_world_root(world_state), enabled)
	world_collision_prepared.emit(world_state, enabled)


func change_world(world_state: WorldState, midpoint_callback := Callable()) -> bool:
	if is_switching or world_state == current_world:
		return false
	is_switching = true
	world_change_started.emit(current_world, world_state)
	if transition_overlay != null and fade_out_duration > 0.0:
		var covered := transition_overlay.color
		covered.a = transition_alpha
		var fade_out := create_tween()
		fade_out.tween_property(transition_overlay, "color", covered, fade_out_duration)
		await fade_out.finished
	apply_world(world_state)
	if midpoint_callback.is_valid():
		midpoint_callback.call()
	world_change_midpoint.emit(world_state)
	if transition_overlay != null and fade_in_duration > 0.0:
		var clear := transition_overlay.color
		clear.a = 0.0
		var fade_in := create_tween()
		fade_in.tween_property(transition_overlay, "color", clear, fade_in_duration)
		await fade_in.finished
	is_switching = false
	return true


func _set_collision_tree(node: Node, enabled: bool) -> void:
	if node is CollisionShape2D or node is CollisionPolygon2D:
		node.set_deferred("disabled", not enabled)
	for child: Node in node.get_children():
		_set_collision_tree(child, enabled)

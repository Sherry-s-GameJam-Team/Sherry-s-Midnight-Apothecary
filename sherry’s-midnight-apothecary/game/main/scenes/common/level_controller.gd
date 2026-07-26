class_name LevelController
extends Node

signal level_ready(level_controller: LevelController)
signal exit_requested(target_level_id: StringName, entry_id: StringName, transition_data: Dictionary)

@export var definition: LevelDefinition
@export var default_spawn_path: NodePath
@export var camera_bounds_path: NodePath
@export var player_path: NodePath = NodePath("../Player")
@export var camera_controller_path: NodePath = NodePath("../TownCameraController")

## Backward-compatible property for older scene contracts.
var level_id: StringName:
	get:
		return get_level_id()

var _spawn_markers: Dictionary[StringName, Marker2D] = {}
var _player: Node
var _camera_bounds: Node

func _ready() -> void:
	add_to_group("level_controller")
	_player = get_node_or_null(player_path)
	_camera_bounds = get_node_or_null(camera_bounds_path)
	_cache_spawn_markers()
	if definition == null:
		push_warning("LevelController has no LevelDefinition: %s" % get_path())
	level_ready.emit(self)

func get_level_id() -> StringName:
	return definition.level_id if definition != null else &""

func get_default_entry_id() -> StringName:
	return definition.default_entry_id if definition != null else &"default"

func get_spawn(entry_id: StringName = &"default") -> Marker2D:
	if _spawn_markers.has(entry_id):
		return _spawn_markers[entry_id]
	if _spawn_markers.has(get_default_entry_id()):
		return _spawn_markers[get_default_entry_id()]
	if default_spawn_path != NodePath():
		return get_node_or_null(default_spawn_path) as Marker2D
	return null

## Backward-compatible name used by existing level tests and older callers.
func get_player_spawn() -> Marker2D:
	return get_spawn()

func get_camera_bounds() -> Node:
	return _camera_bounds

func get_player() -> Node:
	return _player

func get_camera_controller() -> Node:
	return get_node_or_null(camera_controller_path)

func request_exit(target_level_id: StringName, entry_id: StringName = &"default", transition_data: Dictionary = {}) -> void:
	exit_requested.emit(target_level_id, entry_id, transition_data.duplicate(true))

func get_level_contract() -> Dictionary:
	return {
		"level_id": get_level_id(),
		"player_spawn": get_spawn(),
		"camera_bounds": get_camera_bounds(),
		"entry_points": _nodes_in_group_under_root("level_entry"),
		"exit_points": _nodes_in_group_under_root("level_exit"),
		"level_completed": false,
		"music_id": definition.music_id if definition != null else &"",
		"region_id": definition.region_id if definition != null else &"",
	}

static func find_player_camera_controller(level_root: Node) -> Node:
	if level_root == null:
		return null
	for node in level_root.get_tree().get_nodes_in_group("player_camera_controller"):
		if level_root.is_ancestor_of(node):
			return node
	var controller := level_root.get_node_or_null("LevelController") as LevelController
	if controller != null:
		var resolved := controller.get_camera_controller()
		if resolved != null:
			return resolved
	return level_root.get_node_or_null("TownCameraController")

func _cache_spawn_markers() -> void:
	for node in _nodes_in_group_under_root("level_entry"):
		var marker := node as Marker2D
		if marker == null:
			continue
		var entry_id := StringName(str(marker.get_meta("entry_id", "default")))
		_spawn_markers[entry_id] = marker
	var fallback := get_node_or_null(default_spawn_path) as Marker2D
	if fallback != null and not _spawn_markers.has(get_default_entry_id()):
		_spawn_markers[get_default_entry_id()] = fallback

func _nodes_in_group_under_root(group_name: StringName) -> Array[Node]:
	var result: Array[Node] = []
	var scene_root := get_parent()
	if scene_root == null:
		return result
	for node in get_tree().get_nodes_in_group(group_name):
		if scene_root == node or scene_root.is_ancestor_of(node):
			result.append(node)
	return result

class_name HerbSpawnDirector
extends Node2D

## Spawns explicitly assigned herb scenes at authored HerbSpawnPoint locations.
## Plant identity is part of the map authoring and is never randomized.

const DAILY_COLLECTION_PREFIX := "daily_herb_collection"

signal herb_collected(ingredient_id: StringName, amount: int, point_name: StringName)

@export_node_path("Node2D") var spawn_points_path: NodePath = NodePath("../HerbSpawns")
@export var spawning_enabled := true

var _environment: DayLevelEnvironment
var _spawned_herbs: Array[HerbInteractable] = []


func _ready() -> void:
	_environment = get_parent() as DayLevelEnvironment
	if _environment != null:
		_environment.environment_state_changed.connect(_on_environment_state_changed)
	call_deferred("_refresh_spawns")


func _exit_tree() -> void:
	_clear_spawns()


func _on_environment_state_changed(_corrupted: bool) -> void:
	_refresh_spawns()


func _refresh_spawns() -> void:
	_clear_spawns()
	if not spawning_enabled or _environment == null or _environment.is_corrupted():
		return
	var points: Array[HerbSpawnPoint] = _spawn_points()
	for index: int in points.size():
		var point: HerbSpawnPoint = points[index]
		if _was_collected_today(point.name):
			continue
		if point.herb_scene == null:
			push_warning("HerbSpawnPoint %s has no herb_scene assigned." % point.get_path())
			continue
		var herb := point.herb_scene.instantiate() as HerbInteractable
		if herb == null:
			push_error("HerbSpawnPoint %s must instantiate HerbInteractable." % point.get_path())
			continue
		herb.global_position = point.global_position
		herb.z_index = 11
		herb.collected.connect(_on_herb_collected.bind(point.name))
		add_child(herb)
		_spawned_herbs.append(herb)


func _clear_spawns() -> void:
	for herb: HerbInteractable in _spawned_herbs:
		if is_instance_valid(herb):
			herb.queue_free()
	_spawned_herbs.clear()


func _spawn_points() -> Array[HerbSpawnPoint]:
	var container := get_node_or_null(spawn_points_path) as Node2D
	var points: Array[HerbSpawnPoint] = []
	if container == null:
		return points
	for child: Node in container.get_children():
		if child is HerbSpawnPoint:
			points.append(child as HerbSpawnPoint)
	return points


func _on_herb_collected(ingredient_id: StringName, amount: int, point_name: StringName) -> void:
	var data := _player_data()
	if data != null:
		data.tutorial_flags[_collection_key(point_name)] = true
	herb_collected.emit(ingredient_id, amount, point_name)


func set_spawning_enabled(enabled: bool) -> void:
	if spawning_enabled == enabled:
		return
	spawning_enabled = enabled
	if is_node_ready():
		_refresh_spawns()


func collected_point_count() -> int:
	var collected := 0
	for point: HerbSpawnPoint in _spawn_points():
		if _was_collected_today(point.name):
			collected += 1
	return collected


func spawn_point_count() -> int:
	return _spawn_points().size()


func _was_collected_today(point_name: StringName) -> bool:
	var data := _player_data()
	return data != null and bool(data.tutorial_flags.get(_collection_key(point_name), false))


func _collection_key(point_name: StringName) -> String:
	return "%s:%d:%s:%s" % [DAILY_COLLECTION_PREFIX, _current_day(), _environment.debug_scene_id, point_name]


func _current_day() -> int:
	var cursor: Node = self
	while cursor != null:
		for property: Dictionary in cursor.get_property_list():
			if property.get("name") == &"day":
				return int(cursor.get("day"))
		cursor = cursor.get_parent()
	return 0


func _player_data() -> PlayerData:
	return _environment.get_player_data() if _environment != null else null

class_name HerbSpawnDirector
extends Node2D

## Spawns formal alchemy plants at authored Marker2D locations. The order is
## deterministic for a day, while a new day produces a new arrangement.

const HERB_SCENE := preload("res://day/interactables/herb/herb.tscn")
const DAILY_COLLECTION_PREFIX := "daily_herb_collection"
const FIXED_DEW_POINT := &"P10"
const DEW_FLASK_HERB := &"dew_flask_herb"
const FORMAL_INGREDIENT_IDS: Array[StringName] = [
	&"herdsmans_loaf_bush",
	&"stardust_puffy_lion",
	&"grail_lily",
	&"dew_flask_herb",
	&"old_mans_noose",
	&"praise_star_maple",
]

@export_node_path("Node2D") var spawn_points_path: NodePath = NodePath("../HerbSpawns")

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
	if _environment == null or _environment.is_corrupted():
		return
	var points: Array[Marker2D] = _spawn_points()
	var ingredient_ids: Array[StringName] = _daily_ingredient_order(points.size())
	var rotating_index := 0
	for index: int in points.size():
		var point: Marker2D = points[index]
		if _was_collected_today(point.name):
			continue
		var ingredient_id: StringName = DEW_FLASK_HERB if point.name == FIXED_DEW_POINT else ingredient_ids[rotating_index % ingredient_ids.size()]
		if point.name != FIXED_DEW_POINT:
			rotating_index += 1
		var herb := HERB_SCENE.instantiate() as HerbInteractable
		if herb == null:
			continue
		herb.ingredient_id = ingredient_id
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


func _spawn_points() -> Array[Marker2D]:
	var container := get_node_or_null(spawn_points_path) as Node2D
	var points: Array[Marker2D] = []
	if container == null:
		return points
	for child: Node in container.get_children():
		if child is Marker2D:
			points.append(child as Marker2D)
	return points


func _daily_ingredient_order(count: int) -> Array[StringName]:
	var order: Array[StringName] = []
	for ingredient_id: StringName in FORMAL_INGREDIENT_IDS:
		if ingredient_id != DEW_FLASK_HERB:
			order.append(ingredient_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = _current_day() * 7919 + 17
	for index: int in range(order.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: StringName = order[index]
		order[index] = order[swap_index]
		order[swap_index] = temporary
	if count <= order.size():
		var selection: Array[StringName] = []
		for index: int in count:
			selection.append(order[index])
		return selection
	while order.size() < count:
		order.append(FORMAL_INGREDIENT_IDS[order.size() % FORMAL_INGREDIENT_IDS.size()])
	return order


func _on_herb_collected(_ingredient_id: StringName, _amount: int, point_name: StringName) -> void:
	var data := _player_data()
	if data != null:
		data.tutorial_flags[_collection_key(point_name)] = true


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

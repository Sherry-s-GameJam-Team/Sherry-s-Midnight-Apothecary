class_name HomeDayOneLucaDeparture
extends Node

## Starts the second half of the day-one Luca scene once Sherry crosses from
## the bedroom side into Home's main room.

const BEDROOM_EVENT_ID: StringName = &"day_one_bedroom_luca_urgent"
const EVENT_ID: StringName = &"day_one_home_luca_departure"
const INTERACTION_KEY: StringName = &"day_one_home_luca_departure"

@export_node_path("HomeCameraDirector") var camera_director_path: NodePath
@export_node_path("CanvasItem") var luca_path: NodePath

var _camera_director: HomeCameraDirector
var _luca: CanvasItem
var _requested := false


func _ready() -> void:
	_camera_director = get_node_or_null(camera_director_path) as HomeCameraDirector
	_luca = get_node_or_null(luca_path) as CanvasItem
	if _luca != null:
		_luca.visible = false
	if _camera_director != null:
		_camera_director.main_room_crossed.connect(_on_main_room_crossed)


func _on_main_room_crossed() -> void:
	if _requested or not _can_play():
		return
	var runtime := _find_day_runtime()
	if runtime == null:
		return
	_requested = bool(runtime.call("dispatch_story_event_interaction", INTERACTION_KEY))
	if not _requested:
		return
	if _luca != null:
		_luca.visible = true
	runtime.connect(&"story_event_completed", _on_story_event_completed, CONNECT_ONE_SHOT)


func _on_story_event_completed(event_id: StringName) -> void:
	if event_id == EVENT_ID and _luca != null:
		_luca.visible = false


func _can_play() -> bool:
	var runtime := _find_day_runtime()
	return runtime != null \
		and int(runtime.get("day")) == 1 \
		and bool(runtime.call("has_completed_story_event", BEDROOM_EVENT_ID)) \
		and not bool(runtime.call("has_completed_story_event", EVENT_ID))


func _find_day_runtime() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_player_data") and current.has_method("switch_to_level"):
			return current
		current = current.get_parent()
	return null
